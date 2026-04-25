# Changelog

All notable changes to the MRI FieldOps Dashboard are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1] — 2026-04-25

### Fixed
- About tab now displays the correct v1.0.0 baseline release date (`24 April 2026`); previously showed a placeholder date (`18 April 2026`).

### Changed
- `window.APP_VERSION`, `window.APP_BUILD.tag`, and the in-bundle `APP_VERSION` constant bumped to `1.0.1`.
- First end-to-end exercise of the `scripts/release.sh` release flow.

### Notes
- Same code as v1.0.0 plus the date-string fix. Safe drop-in upgrade; no behavioral change.

---

## [1.0.0] — 2026-04-24

**Baseline release.** First tagged, rollback-safe production build. Everything prior is folded into this line; future entries track changes from this point forward.

### Core capabilities
- Single-file HTML app (`index.html`) deployed to GitHub Pages; no build step.
- Role-gated UI — `superadmin`, `admin`, `manager`, `viewer` — enforced via CSS classes + Supabase RLS.
- Auth + data via Supabase (Postgres + REST + Auth). Prod and staging are separate Supabase projects.
- Two deployment tracks: `main` → `/` (prod), `staging` → `/staging/` (staging). Pushing `staging` also redeploys main via GitHub Actions.

### Shipped features
- **Dashboard** — KPI grid, alert banner, ticket cards, role-aware tiles.
- **Service History** — 13-column ticket list with month + modality filters, CSV + PDF export.
- **Open Tickets** — pending workload view with filter bar.
- **PM Schedules** — master schedule with structured completion flow, role-gated actions, engineer attribution, month-picker without IST drift.
- **Install Base** — xlsx v2.1 as single source of truth; AN025 KVC Diagnostics (Mysore) included.
- **Field Team** — engineer roster with admin-only add/reset/delete.
- **Flags & Ambiguities** — admin-only; 24h auto-clear + auto-detect on xlsx upload.
- **Engineer Performance** — admin + manager; per-metric drill-down, PM compliance with graceful fallback when migration `0001` is pending.
- **Reports** — aggregate rollups.
- **Audit Log** — superadmin-only.
- **About** — objective + scope copy.
- **XLSX upload** — preserves resolved ambiguities across uploads, rolls `pm_schedule` forward.

### Known limits
- No real-time — users refresh to see others' changes.
- Granular role permissions enforced per-tab, not per-record.
- No custom domain; served from `*.github.io`.

### Database state at baseline
- Schema: `01_schema.sql`.
- Seed data: `02_seed_data.sql`.
- Applied migrations: `db/migrations/0001_pm_completions_engineer_ids.sql`.
- Prod project: `mvwhubatooliudbvythy`.
- Staging project: `qupkpprptopyejbnslev`.

### Bundle fingerprint
- Commit: `4e38616`
- Size: 446,616 bytes
- File: `index.html` (single file)
- Prod etag at release: `69eb524d-6d098`
- Snapshot archived: `releases/v1.0.0/index.html`
