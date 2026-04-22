-- 0001_pm_completions_engineer_ids.sql
-- Adds multi-engineer credit support to PM completions.
--
-- Why:
--   A PM visit may be performed by 1..N engineers (two regional primaries,
--   a primary + helper, or a cross-region solo coverage). The legacy
--   `engineer_id` scalar column can't express that, so PM Compliance
--   attribution mis-credits anyone beyond the first engineer.
--
-- What:
--   - Adds `engineer_ids text[]` to pm_completions.
--   - Adds a GIN index so per-engineer filters stay fast.
--   - Keeps `engineer_id` in place for audit / back-compat; the app will
--     write both (engineer_id = engineer_ids[1]) and read engineer_ids
--     first, falling back to engineer_id when the array is null.
--
-- Apply in Supabase SQL editor. Idempotent.

alter table public.pm_completions
  add column if not exists engineer_ids text[];

create index if not exists pm_completions_engineer_ids_idx
  on public.pm_completions using gin(engineer_ids);

-- Backfill is performed client-side on first admin load after deploy:
-- the app looks up each completion's matching service report (same
-- customer, PMS/PM call_type, within ±15 days of completion_date),
-- derives engineer_ids from the ticket's engineer field, and pushes
-- unresolvable rows to the ambiguities table for admin review.
