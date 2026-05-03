-- ═════════════════════════════════════════════════════════════════════
-- ROLLBACK for 0002_lock_audit_log_writes.sql
--
-- Restores audit_log to its prior permissive state: any authenticated
-- user can UPDATE / DELETE.
--
-- Use only if the migration breaks legitimate app behavior (none expected,
-- since the app never UPDATEs or DELETEs audit_log).
-- ═════════════════════════════════════════════════════════════════════

-- Drop the restrictive deny policies
drop policy if exists "audit_log_immutable_update" on public.audit_log;
drop policy if exists "audit_log_immutable_delete" on public.audit_log;

-- Restore table-level grants
grant update, delete on public.audit_log to authenticated;
-- anon was never granted these in the schema; do not re-grant.

-- Recreate the permissive policies under the original naming convention
-- so 01_schema.sql expectations still match.
drop policy if exists "auth_update_audit_log" on public.audit_log;
drop policy if exists "auth_delete_audit_log" on public.audit_log;

create policy "auth_update_audit_log" on public.audit_log
  for update
  to authenticated
  using (true)
  with check (true);

create policy "auth_delete_audit_log" on public.audit_log
  for delete
  to authenticated
  using (true);

comment on table public.audit_log is null;
