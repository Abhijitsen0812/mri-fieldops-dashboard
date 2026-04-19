-- ═══════════════════════════════════════════════════════════════════
-- MRI FieldOps Dashboard — Supabase Schema
-- Run this ONCE in the Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- ── Extension for UUIDs ────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── 1. Engineers ───────────────────────────────────────────────────
create table public.engineers (
  id              text primary key,
  name            text not null,
  region          text not null,
  email           text,
  aliases         text[] default '{}',
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index on public.engineers (region);

-- ── 2. Install base (CONFIG_ASSETS) ────────────────────────────────
create table public.config_assets (
  code            text primary key,
  ast_id          text,
  name            text not null,
  tesla           text,
  model           text,
  town            text,
  state           text,
  channel         text,
  gradient        text,
  sw              text,
  compressor      text,
  coldhead        text,
  alias_of        text references public.config_assets(code),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index on public.config_assets (town);
create index on public.config_assets (name);

-- ── 3. CMC contracts ───────────────────────────────────────────────
create table public.cmc_contracts (
  id              uuid primary key default uuid_generate_v4(),
  sn              integer,
  customer        text not null,
  town            text,
  model           text,
  contract        text,
  start_date      date,
  end_date        date,
  asset_code      text references public.config_assets(code),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index on public.cmc_contracts (asset_code);
create index on public.cmc_contracts (customer);

-- ── 4. PM schedule ─────────────────────────────────────────────────
create table public.pm_schedule (
  id              text primary key,
  customer        text not null,
  model           text,
  contract        text,
  town            text,
  region          text,
  freq            integer default 2,
  contract_start  date,
  contract_end    date,
  last_pms        date,
  next_pms        date,
  status          text default 'active',
  asset_code      text references public.config_assets(code),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index on public.pm_schedule (region);
create index on public.pm_schedule (next_pms);

-- ── 5. Service tickets (the biggest table) ─────────────────────────
create table public.tickets (
  id              text primary key,
  month           text,
  src_row         integer,
  customer_raw    text,
  customer        text,
  asset_code      text,
  town            text,
  state           text,
  contract        text,
  call_date       date,
  call_type       text,
  model           text,
  sys_status      text,
  issue           text,
  attended_date   date,
  engineer        text,
  parts           text,
  parts_req_date  date,
  parts_recv_date date,
  parts_status    text,
  sys_up_date     date,
  resolution      text,
  status          text,
  orphaned        boolean default false,
  unmatched       boolean default false,
  ambiguities     jsonb default '[]'::jsonb,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index on public.tickets (month);
create index on public.tickets (status);
create index on public.tickets (asset_code);
create index on public.tickets (customer);
create index on public.tickets (call_date);
create index on public.tickets (engineer);

-- ── 6. Ambiguity reviews ───────────────────────────────────────────
create table public.ambiguities (
  id              text primary key,
  month           text,
  row_num         integer,
  customer        text,
  issue           text,
  status          text default 'Review Required',
  sys_status      text,
  flags           text[],
  suggestion      text,
  resolution      text,
  review          jsonb,  -- {reviewer, decision, notes, timestamp} when reviewed
  resolved_by     uuid references auth.users(id),
  resolved_at     timestamptz,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ── 7. Upload audit log (optional, but valuable) ───────────────────
create table public.upload_log (
  id              uuid primary key default uuid_generate_v4(),
  uploaded_by     uuid references auth.users(id),
  uploaded_at     timestamptz default now(),
  source_file     text,
  ticket_count    integer,
  months          text[]
);

-- ── updated_at triggers ────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger engineers_updated_at       before update on public.engineers       for each row execute function public.set_updated_at();
create trigger config_assets_updated_at   before update on public.config_assets   for each row execute function public.set_updated_at();
create trigger cmc_contracts_updated_at   before update on public.cmc_contracts   for each row execute function public.set_updated_at();
create trigger pm_schedule_updated_at     before update on public.pm_schedule     for each row execute function public.set_updated_at();
create trigger tickets_updated_at         before update on public.tickets         for each row execute function public.set_updated_at();
create trigger ambiguities_updated_at     before update on public.ambiguities     for each row execute function public.set_updated_at();

-- ═══════════════════════════════════════════════════════════════════
-- ROW-LEVEL SECURITY (RLS)
--
-- Without RLS, your anon key (visible in browser) would let anyone
-- read/write. These policies restrict access to authenticated users.
-- ═══════════════════════════════════════════════════════════════════

alter table public.engineers      enable row level security;
alter table public.config_assets  enable row level security;
alter table public.cmc_contracts  enable row level security;
alter table public.pm_schedule    enable row level security;
alter table public.tickets        enable row level security;
alter table public.ambiguities    enable row level security;
alter table public.upload_log     enable row level security;

-- Policy: any authenticated user can SELECT and modify.
-- Simpler than per-role for small team; can be tightened later.
do $$
declare
  t text;
begin
  foreach t in array array['engineers','config_assets','cmc_contracts','pm_schedule','tickets','ambiguities','upload_log']
  loop
    execute format('create policy "auth_read_%s" on public.%I for select to authenticated using (true)', t, t);
    execute format('create policy "auth_write_%s" on public.%I for insert to authenticated with check (true)', t, t);
    execute format('create policy "auth_update_%s" on public.%I for update to authenticated using (true) with check (true)', t, t);
    execute format('create policy "auth_delete_%s" on public.%I for delete to authenticated using (true)', t, t);
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════════
-- Done. Run 02_seed_data.sql next to populate with current data.
-- ═══════════════════════════════════════════════════════════════════
