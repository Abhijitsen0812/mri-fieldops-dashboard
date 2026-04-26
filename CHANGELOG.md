# Changelog

All notable changes to the MRI FieldOps Dashboard are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.2] — 2026-04-26

### Fixed
- **Dashboard KPI cards no longer falsely advertise clickability** (audit F-01). The base `.kpi-card` rule had `cursor: pointer` even though the dashboard's six top-row tiles (Total Service Calls, Incidents, PM Calls, Open Tickets, Data Flags, Install Base Covered) have no click handler. The base now uses `cursor: default`; clickable PM tiles still opt in with inline `cursor: pointer + onclick`; tooltip cards keep `cursor: help`.
- **Install Base panel header now reads the live count** (audit F-12). Was hardcoded "🏥 Install Base — 22 Systems" and out of date (actual count is 25). Now driven by `CONFIG_ASSETS.length` via a `<span id="install-base-count">`; with a search active, shows `<filtered>/<total>`.
- **Engineer Performance: REOPEN RATE placeholder tile removed** (audit F-14). The tile shipped the literal copy "v2 — not tracked yet" to end users. PM COMPLIANCE now spans the row. Will reinstate as a real metric once reopen tracking lands.
- **`Loaded: …` console log deduped** (audit F-16). `loadAllFromDB()` was logging the identical line on every realtime reload — 4× per sign-in observed. Now logs only when one of the counts or the months list actually changes (fingerprinted via `window._lastLoadFingerprint`).
- **Form controls inherit the body font** (audit D-02). Login submit / forgot-password / recovery buttons rendered in Arial because UA defaults override the body font on form controls. Added a global `button, input, select, textarea { font-family: inherit; }` reset.

### Notes
- All five fixes are view-layer / display-only. No auth, RLS, write paths, or data flow touched. Bundle grows 1,749 bytes (mostly comments referencing audit IDs).
- Companion document: `docs/STAGING_AUDIT_2026-04-26.md` — staging audit covering all 11 pages × 3 roles, with a phase-wise improvement roadmap. Phase 0 = this release.
- Four audit findings (F-03, F-05, F-08, F-11) were re-verified against code and reclassified as false positives — caused by my browser audit's use of `textContent` (which strips display:none and block-level breaks) and stale modal contamination between test steps. Documented in the Phase 0 commit message.

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
