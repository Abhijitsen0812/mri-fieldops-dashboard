-- ═════════════════════════════════════════════════════════════════════
-- VERIFICATION — run after migration 0002. All five sections should
-- return the expected result. Run in the Supabase SQL Editor.
-- ═════════════════════════════════════════════════════════════════════

-- 1. RLS is enabled on audit_log
--    Expected: relrowsecurity = true
select relname, relrowsecurity
from pg_class
where relname = 'audit_log'
  and relnamespace = 'public'::regnamespace;

-- 2. The two restrictive deny policies exist with the correct shape
--    Expected: 2 rows; permissive = 'RESTRICTIVE'; qual = 'false'
select policyname, cmd, permissive, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'audit_log'
  and policyname in ('audit_log_immutable_update', 'audit_log_immutable_delete')
order by policyname;

-- 3. UPDATE and DELETE grants are revoked from authenticated and anon
--    Expected: 0 rows
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'audit_log'
  and grantee in ('authenticated', 'anon')
  and privilege_type in ('UPDATE', 'DELETE');

-- 4. INSERT and SELECT grants remain for authenticated
--    Expected: at least 'INSERT' and 'SELECT' for grantee 'authenticated'
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'audit_log'
  and grantee = 'authenticated'
order by privilege_type;

-- 5. Behavioral test — must run as an authenticated user (NOT service_role)
--    in the Supabase SQL Editor's "Run as authenticated" mode, or via REST
--    with a real user JWT. service_role bypasses RLS and will succeed
--    even after the migration, which is by design.
--
--    Expected:
--      INSERT  → succeeds
--      UPDATE  → fails with: "new row violates row-level security policy"
--                or "permission denied for table audit_log"
--      DELETE  → same failure as UPDATE
--
--    Do not run this block as service_role — the result will be misleading.

-- INSERT (must succeed):
-- insert into public.audit_log (user_email, action, details)
--   values ('verify@test', 'verify_migration_0002', '{"step":"insert"}'::jsonb);

-- UPDATE (must fail):
-- update public.audit_log
--   set details = '{"tampered":true}'::jsonb
--   where action = 'verify_migration_0002';

-- DELETE (must fail):
-- delete from public.audit_log
--   where action = 'verify_migration_0002';
