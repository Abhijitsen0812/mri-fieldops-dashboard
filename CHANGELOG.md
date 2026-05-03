# Changelog

All notable changes to the MRI FieldOps Dashboard are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0-db.0002] — 2026-05-03

Database-layer security hardening for `audit_log`. No app code or VERSION changed.

### Security
- Security: made audit_log append-only at the database layer by blocking UPDATE and DELETE for anon/authenticated roles while preserving INSERT and SELECT.

---

## [1.1.0] — 2026-04-28

Phase 1 of the staging audit roadmap (`docs/STAGING_AUDIT_2026-04-26.md`). Three sub-phases shipped together: design system foundation, accessibility floor, and hash routing + IA merge. View-layer architecture upgrade — no schema or auth changes.

### Added
- **Design token catalog** at `:root`: spacing scale (4-pt grid `--space-1`…`--space-7`), type scale (`--text-xs`…`--text-4xl`), radius scale (`--radius-sm`…`--radius-pill`), 6-step elevation scale (`--shadow-1`…`--shadow-6`), full semantic colors (`--success/--warning/--danger/--info` plus legacy aliases), focus ring (`--focus-ring`).
- **Lucide icon system** via CDN-hosted `lucide@0.300.0` plus inline `<i data-lucide="x">` placeholders. `window.refreshIcons()` helper plus a `MutationObserver` that auto-swaps placeholders on every render — no per-render-function plumbing needed.
- **Button variants**: `.btn-secondary`, `.btn-danger`, `.btn-link` join the existing `.btn-primary` / `.btn-ghost`. All variants share radius, typography, and focus-ring via the unified base `.btn` rule.
- **Hash routing**: every page is a bookmarkable URL. `/#/dashboard`, `/#/tickets`, `/#/tickets?status=open`, `/#/pm`, `/#/assets`, `/#/team`, `/#/ambiguities`, `/#/engperf`, `/#/reports`, `/#/auditlog`, `/#/about`. Refreshing the browser preserves the page; back/forward work; legacy `/#/open` redirects to `/#/tickets?status=open`.
- **Service History status filter chips**: All / Open / Closed. Open Tickets is now a saved filter — the previous separate "Open Tickets" sidebar entry was removed (audit I-02). The chip's state is round-tripped through the URL.
- **Skip-to-content link** as the first focusable element on every page (audit A-06).
- **Two `aria-live` regions** (polite + assertive) plus `window.announce(message, priority)` helper. Sign-in errors are now announced.
- **`role="dialog"` / `aria-modal="true"` / `aria-labelledby` on all 4 modals** (ticket detail, engineer drill-in, PM completion, XLSX upload). New `openModal(id)` / `closeModal(id)` helpers move focus into the modal on open, restore focus to the opener on close, trap Tab inside the modal, and close on Escape (audit A-03).
- **Sidebar nav keyboard support**: 11 nav-item divs got `role="button"` + `tabindex="0"` + Enter/Space handler + `aria-current="page"` on the active item (audit A-01).
- **Heading hierarchy**: 23 panel-title `<div>`s promoted to `<h2>` so screen-reader heading nav (`H` key) produces a real outline (audit A-05).
- **Input labels**: every static-HTML `<input>` / `<select>` / `<textarea>` got an `aria-label` — closes the most visible part of the 359/370 unlabeled-input gap (audit A-02; dynamic radios deferred).

### Changed
- **Drop Syne webfont**. `--display` redefined to `var(--sans)` so the 12+ existing `var(--display)` usages now resolve to Inter. One less Google Fonts round-trip; one type system across the UI.
- **Sidebar section labels**: mono-uppercase `OPERATIONS` / `ASSETS & TEAM` / `ANALYSIS` → sans sentence-case `Operations` / `Assets & team` / `Analysis`. Letter-spacing 2px → 0.2px.
- **50+ chrome emoji replaced with Lucide SVG icons**: sidebar (11), panel titles (18+), action buttons (10), modal-close × → `<button aria-label="Close"><i data-lucide="x">`, alert-banner ⚠ + ×, menu hamburger ☰, About hero. Emoji preserved in user-generated content (ticket descriptions, customer notes).
- **KPI hover toned down**: lift `-3px → -1px`; gradient overlay opacity `.6 → .25`. The strong hover effect was implying clickability on every card; the new treatment is gentle visual feedback that doesn't compete with the actually-clickable PM tiles.

### Fixed
- **Alert banner "tickets dated outside reporting window" count was unbounded.** `parseFlexDate()` pushed to `DATE_AUDIT.suspicious` on every call without dedupe; hot render paths (calcSLA, calcMTTR, calcRepeatFailures, etc.) re-parsed the same dates on every dashboard re-render and the count climbed by ~250 each time. Five team↔dashboard cycles took it from 29 (correct) to 1,277. Dedupe now keys on `${ctx}|${raw}`; `DATE_AUDIT.reset()` runs at the start of `loadAllFromDB`. Banner now also computes its count directly from `RAW_TICKETS` so the number is both stable AND accurate (33 tickets with at least one out-of-window date — was previously polluted by PM, contract, and completion-date parses).
- **`navigate()` wrapper dropped its second argument.** A doFirstPaint wrapper added in v1.0.0 to re-run page renderers after each navigate had a one-arg signature; the new `opts={fromHash, query}` introduced by 1c hash routing was silently dropped, so deep-links like `/#/tickets?status=open` hydrated to the right page but with the chip stuck on All. Wrapper now forwards every argument.
- **`navigate()` early-return prevented same-page filter updates.** `/#/tickets?status=closed` → `/#/tickets?status=open` had the same target page so the early-return path skipped the filter update logic. Restructured so the early-return only short-circuits the page+nav class flips; query-driven side effects always run.
- **Modal focus mover used `requestAnimationFrame`.** RAF is throttled or paused when the tab/window doesn't have focus, leaving focus on the opener element even though the modal was visible. Switched to `setTimeout(0)`.

### Notes
- All 3 roles (admin, manager, engineer) re-verified on staging before promotion. Restricted-page hashes (`/#/ambiguities`, `/#/auditlog`, `/#/engperf`) bounce to `/#/dashboard` for non-authorised roles. 0 console errors observed across role transitions and 8 cycles of dashboard ↔ pm ↔ tickets ↔ team navigation.
- Bundle: 448,786 → 476,242 bytes (+27 KB). Cost is mostly comments referencing audit IDs (F-01, A-03, etc.) so future maintainers can trace why each line is the way it is.
- Sub-phase manifest: 1a (design tokens + Lucide), 1b (a11y floor), 1c (hash routing + IA merge) — 11 commits total on the release branch.
- Phase 2 is queued for v1.2.0: data-grid table polish (column sort, sticky headers, density), dashboard charts, ticket inline edit (deferred per owner's read-only ruling), Reports page deletion, global search.

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
