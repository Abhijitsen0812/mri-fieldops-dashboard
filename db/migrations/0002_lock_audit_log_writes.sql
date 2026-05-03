-- ═════════════════════════════════════════════════════════════════════
-- 0002_lock_audit_log_writes.sql
--
-- Make public.audit_log effectively append-only at the database layer.
--
-- BEFORE:
--   audit_log has RLS enabled. Any authenticated JWT could in principle
--   issue REST UPDATE / DELETE against audit_log and rewrite or erase
--   audit history. The app never does this; only the DB lacks a guard.
--
-- AFTER:
--   INSERT  — unchanged. App continues to write events via authenticated
--             session (used by logAudit() in index.html line 6369).
--   SELECT  — unchanged. App's audit page (superadmin-gated frontend)
--             continues to read via _sb.from('audit_log').select(...).
--             Read-tightening deferred to v1.3.0 enterprise security pkg.
--   UPDATE  — denied for authenticated AND anon roles.
--   DELETE  — denied for authenticated AND anon roles.
--   service_role — unaffected (bypasses RLS; needed for backups, future
--                  retention jobs, and emergency admin via SQL Editor).
--
-- Idempotent: safe to re-apply any number of times.
-- Apply order: STAGING first, verify, then PROD.
-- ═════════════════════════════════════════════════════════════════════

-- Pre-flight: confirm RLS is enabled (no-op if it already is).
alter table public.audit_log enable row level security;

-- ── Layer 1: drop any existing permissive UPDATE / DELETE policies ───
-- Names are unknown because audit_log was created outside source control.
-- Discover and drop dynamically.
do $$
declare p record;
begin
  for p in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'audit_log'
      and cmd in ('UPDATE', 'DELETE')
      -- Don't drop the restrictive deny policies we're about to (re)create.
      and policyname not in (
        'audit_log_immutable_update',
        'audit_log_immutable_delete'
      )
  loop
    execute format('drop policy if exists %I on public.audit_log', p.policyname);
  end loop;
end $$;

-- ── Layer 2: add RESTRICTIVE deny policies ──────────────────────────
-- Restrictive policies use AND semantics — they MUST pass alongside any
-- permissive policy. USING (false) means: never pass. Result: any UPDATE
-- or DELETE attempt is blocked even if a future permissive policy is
-- mistakenly added.
drop policy if exists "audit_log_immutable_update" on public.audit_log;
drop policy if exists "audit_log_immutable_delete" on public.audit_log;

create policy "audit_log_immutable_update" on public.audit_log
  as restrictive
  for update
  to public
  using (false)
  with check (false);

create policy "audit_log_immutable_delete" on public.audit_log
  as restrictive
  for delete
  to public
  using (false);

-- ── Layer 3: revoke table-level UPDATE/DELETE grants ────────────────
-- Even before RLS evaluation, PostgreSQL checks GRANTs. Revoking grants
-- gives an extra wall: a future schema migration that accidentally
-- creates a permissive UPDATE policy still won't work without the grant.
revoke update, delete on public.audit_log from authenticated;
revoke update, delete on public.audit_log from anon;

-- INSERT and SELECT grants are intentionally left untouched.
-- service_role grants are intentionally left untouched (bypassrls anyway).

-- ── Recordkeeping ───────────────────────────────────────────────────
comment on table public.audit_log is
  'Append-only audit trail. UPDATE and DELETE blocked by restrictive RLS '
  'policies and revoked grants since migration 0002. Use service_role for '
  'any operational maintenance.';
