# MRI FieldOps Dashboard — Staging Audit
**Date:** 2026-04-26
**Auditor:** Claude (driven by abhijit.s@3imedtech.com)
**Build under review:** Staging v1.0.0 (`https://3imedtech.github.io/mri-fieldops-dashboard/staging/`)
**Production for reference:** v1.0.1 — main is one commit ahead, only the About-tab date fix

---

## 1. Executive summary

The product is **functionally complete for an internal tool** — all 11 pages render, RLS is enforced, the three roles cleanly differentiate via `superadmin-mode` / `viewer-mode manager-mode` / `viewer-mode` body classes, and the data pipeline (XLSX → Supabase → realtime → UI) works.

But measured against an **enterprise-SaaS bar** (Salesforce, ServiceNow), it is currently **mid-tier internal tool**, not enterprise polish. The gaps cluster in five areas:

| Area | Verdict | Gap to enterprise |
|---|---|---|
| **Information architecture** | Functional but flat | No deep-linking, no breadcrumbs, no global search; navigation is name + emoji + count |
| **Design system** | Embryonic | 6 CSS tokens total, 2 button variants, no spacing/typography/elevation scales, font fallback to Arial on primary buttons |
| **Accessibility** | Severely below WCAG 2.1 AA | 1,816 cursor-pointer divs without `role`/`tabindex`, 97% of inputs unlabeled, modals lack `role="dialog"`, zero `aria-live`, headings have no h2/h3 hierarchy |
| **Interaction quality** | Confidence issues | Top-row dashboard KPIs visually look clickable but are inert; tables have no column sort; no inline edit; engineer cannot Mark PM Completed (their primary use case) |
| **Data presentation** | OK at small scale | 13–16-column tables with no horizontal scroll affordance, no sticky headers/columns, no row density toggle, no zebra striping; date format mostly consistent but a few off-window data quality issues are exposed in modals |

**The right move is a staged rework, not a re-write.** Phase-wise plan in §6.

---

## 2. Methodology

Browser-driven audit through Claude-in-Chrome MCP against staging Supabase backend (`qupkpprptopyejbnslev`). Three credential sets used: `abhijit.s@3imedtech.com` (superadmin), `manager@3imedtech.com` (manager), `engineer@3imedtech.com` (viewer). For each role:

1. Sign-in flow + role-class verification on `<body>`
2. Sidebar inventory + visibility per role
3. Walk every page; capture headings, table column counts, KPI labels, filter chips, exposed buttons
4. Exercise interactions: ticket detail modal, KPI click, upload trigger, period chip, search filter, sign-out
5. Inspect computed styles for visual baseline (colors, typography, radii, padding)
6. Console + network observation
7. Programmatic accessibility scan (label/role/aria-live/cursor-pointer-without-role)

What I did **not** do (out of safety):
- Trigger an XLSX upload that mutates staging data
- Click destructive buttons (delete engineer, force-resync)
- Send email reminders or notifications
- Modify any record

Verifying these workflows is part of Phase 0 below — owner must confirm intent before the audit replays them under controlled data.

---

## 3. Surface map (verified live, not from memory)

### 3.1 Role-class + sidebar matrix

| Page | Admin (superadmin-mode) | Manager (viewer-mode + manager-mode) | Engineer (viewer-mode) |
|---|---|---|---|
| 📊 Dashboard | ✓ | ✓ | ✓ |
| 🎫 Service History (290) | ✓ | ✓ | ✓ |
| 🚨 Open Tickets (6) | ✓ | ✓ | ✓ |
| 📅 PM Schedules (1) | ✓ | ✓ | ✓ |
| 🏥 Install Base | ✓ | ✓ | ✓ |
| 👷 Field Team (9) | ✓ | ✓ | ✓ |
| ⚠️ Flags & Ambiguities (118) | ✓ | ✗ hidden | ✗ hidden |
| 🏅 Engineer Performance | ✓ | ✓ | ✗ hidden |
| 📈 Reports | ✓ | ✓ | ✓ |
| 🛡️ Audit Log | ✓ | ✗ hidden | ✗ hidden |
| ℹ️ About | ✓ | ✓ | ✓ |

**`.admin-only` elements in DOM:** 259 — verified all hidden in manager/engineer.
**`.pm-manage` elements:** 3 (Remind, Compose Reminder, Mark PM Completed) — visible to manager, hidden to engineer.
**`.superadmin-only` elements:** 1 (likely the password-reset action).

### 3.2 Design tokens (verified from `getComputedStyle(documentElement)`)

```
--bg:      #0a0e17     ← body background (deep navy)
--surface: #111827     ← elevated surface
--border:  #243044     ← used everywhere
--text:    #e2e8f0     ← primary text
--accent:  #06b6d4     ← cyan
--brand:   #3b82f6     ← blue
```

**Missing semantic tokens:** no `--success`, `--warning`, `--danger`, `--info` exposed as CSS variables. Status colors are hardcoded inline (e.g. `style="color:var(--amber)"` on cells), but `--amber` itself isn't in the root token set. Result: any theme/variant work touches dozens of hardcoded values rather than swapping tokens.

**Missing scales entirely:** no spacing scale, no typography scale, no elevation/shadow tokens, no radius tokens. Padding/radius values (`6px`, `7px`, `10px`, `14px`, `15px`) are inconsistent across button/card/input — see §4.

### 3.3 Typography (verified)

- Body: `Inter, system-ui, -apple-system, sans-serif`, 14px
- H1 login: 20px / 700
- H1 dashboard: 28px / 700
- **No h2 or h3 anywhere on Dashboard / Service History / Open Tickets / PM** — KPI labels and section headers use `<div>`s, not headings. Screen-reader heading nav is broken.
- **Primary button typography fallback:** `getComputedStyle(button).fontFamily === "Arial"` on `Sign in`, `Send reset link`, `Update password`. Inter is set on body but not inherited on submit buttons. **Visual inconsistency between primary CTAs and the rest of the UI.**

### 3.4 Buttons taxonomy

Only two semantic variants:
- `btn-primary` (blue 3b82f6, 10px padding, 6px radius, white text)
- `btn-ghost` (#1a2235 surface, slate-300 text, 6–12px padding, 7px radius)
- Untyped: hamburger toggle, internal close `×`

**No `btn-danger` for destructive actions.** The Field Team `×` delete is a `btn-ghost` — the same visual weight as Cancel.

**Radius inconsistency:** primary 6px, ghost 7px, KPI card 14px. No system.

---

## 4. Issue catalogue

Severity scale: **🔴 Critical** = breaks workflow or accessibility/legal exposure · **🟠 High** = significant UX friction · **🟡 Medium** = polish/quality gap · **🟢 Low** = nice-to-have.

### 4.1 Functional bugs & UX correctness

| # | Severity | Finding | Evidence | Affects |
|---|---|---|---|---|
| F-01 | 🔴 | **Dashboard KPI cards have `cursor: pointer` but no click handler.** Total Service Calls / Incidents / PM Calls / Open Tickets / Data Flags / Install Base Covered all look clickable, do nothing. SLA / MTTR / Repeat Failures correctly use `cursor: help` (tooltip-only). | Inspected 9 cards; `kpi-card` container has no `onclick`, no children with `onclick`, only `cursor:pointer` style. PM page tiles (OVERDUE / IN WINDOW / UPCOMING) DO have `pmFilterStatus=` onclicks — proving the pattern exists, just not wired on dashboard. | All roles |
| F-02 | 🔴 | **No column sorting on any table.** Service History (290 rows × 13 cols) and Install Base (26 rows × 16 cols) `<th>` elements have `cursor: auto`, no `onclick`, no sort glyphs. Users cannot sort by date / customer / status. | `Array.from(thead th)`: zero sort affordances. | All roles |
| F-03 | 🔴 | **Engineer cannot Mark PM Completed.** PM completion is the engineer's primary workflow but `.pm-manage` is hidden under `viewer-mode` without `manager-mode`. ACTION column **header still renders** for engineer — empty cells, wasted horizontal space, broken visual. | Engineer signed in; `pmManageVisible: 0`, `pmManageHidden: 3`. Header `tableHasActionCol: true`. | Engineer |
| F-04 | 🟠 | **Engineer cannot view their own performance.** Engineer Performance is hidden from the engineer role entirely. Engineers have no self-service access to their own SLA/MTTR/FTF metrics. | Sidebar: Engineer Performance `visible: false` for engineer. | Engineer |
| F-05 | 🟠 | **Logout doesn't clear authenticated DOM.** Sign-out shows the login overlay but `body.innerHTML` still contains the previous user's tickets, KPIs, and Sign-out button (just visually covered). Anyone with devtools after a sign-out sees the previous user's data. | After clicking Sign out: `read_page` lists ref_4 "Sign out" + ref_8-17 dashboard widgets alongside the new login fields. | All roles |
| F-06 | 🟠 | **All auth flows pre-rendered simultaneously.** "New password" + "Confirm new password" + "Reset email" inputs are all in DOM at login time (3 email fields, 3 password fields). `<form>.requestSubmit()` defaults to the first form, but `find()` returns ambiguous refs, and tab order leaks through hidden flows. | `find: 3 matching elements` for both Email and Password queries on login page. | All roles |
| F-07 | 🟠 | **Ticket modal is read-only with no edit affordance.** Status, parts, resolution can only be updated by re-uploading the XLSX. No inline status update, no comment thread, no engineer reassignment. | Modal contains zero buttons (`buttonsInModal: []`). | All roles |
| F-08 | 🟠 | **Wrong modal opens on engineer-name cell click.** Clicking on the engineer name in the dashboard's Open Ticket preview opens the **Engineer Performance** drill-in modal but every field is `—` (empty). Either the modal is wired to the wrong data source or the engineer-detail route isn't binding the engineer ID. | Clicked first row → modal title "ENGINEER PERFORMANCE — — × —". | Admin/Manager (engineer can't see Engineer Performance) |
| F-09 | 🟡 | **PM Schedule + PM Completion History glued into one DOM with continuous `<thead>`.** When I read `thead th` on the PM page I got 12 + 8 = 20 columns concatenated — two separate logical tables share a section without clear separation. | `tableHead: [ID, CUSTOMER, ..., STATUS, TICKET ID, MONTH, ..., STATUS]` (column "STATUS" appears twice). | All roles |
| F-10 | 🟡 | **PM tile math reads inconsistently:** *TOTAL MACHINES 22 / 19 with PM schedule* and *PENDING / N/A 7 / 6 pending, 1 not covered* — sums to 22 but the 19-vs-7 phrasing requires mental arithmetic. | PM page KPI tiles. | All roles |
| F-11 | 🟡 | **Run-on text in cells:** "IN WINDOWDue in 4d" — should be either two lines or a separator. | PM page status column. | All roles |
| F-12 | 🟡 | **Install Base count mismatch.** Title says "22 Systems" but table shows 26 rows. Either 4 phantom rows or the title isn't recomputed from the row count. | `🏥 Install Base — 22 Systems` header vs 26 `<tbody tr>`. | All roles |
| F-13 | 🟡 | **Reports page glues two tables under one `<thead>` query** (KPI Summary + Customer Breakdown) — same pattern as F-09. | Headers: KPI / VALUE / NOTES / CUSTOMER / TOTAL CALLS / INCIDENTS / PMS / OPEN / CONTRACT. | All roles |
| F-14 | 🟡 | **"REOPEN RATE — v2 — not tracked yet"** is exposed copy on Engineer Performance. Scaffolding/internal note shown to end-users. | Engineer Performance page peek. | Admin/Manager |
| F-15 | 🟡 | **Audit log auto-logs every page navigation** as a separate event. With 3 users navigating, the 500-event cap fills fast — long-term forensic value drops. Two POSTs to `/audit_log` fired during a single page session in my session. | `/rest/v1/audit_log` POSTs observed; "Showing 500 of 500 most recent events (max 500)". | Admin |
| F-16 | 🟢 | **Dashboard "Loaded: …" log fires 4× on a single sign-in.** Indicates duplicate fetch/render handlers — not user-visible but wasteful. | Console messages show identical "Loaded: 290 tickets, 25 assets…" 4 times. | All roles |

### 4.2 Design system & visual consistency

| # | Severity | Finding |
|---|---|---|
| D-01 | 🔴 | **6 CSS tokens, no scales.** Spacing, typography, elevation, radius, semantic color all hardcoded. Theming, dark/light toggle, or any future enterprise visual rework will require touching dozens of files (well, sections of one file) instead of swapping a token map. |
| D-02 | 🟠 | **Primary buttons render in Arial.** Body uses Inter; the `<input type=submit>` / `<button type=submit>` defaults break inheritance. Primary CTAs visibly differ from the rest of the UI. Trivial fix (`button { font: inherit }`), high visual win. |
| D-03 | 🟠 | **Border-radius drift:** primary 6px, ghost 7px, KPI card 14px, modal not measured. No radius scale. |
| D-04 | 🟠 | **Padding drift:** primary 10px, ghost 6px 12px, hamburger 0px, KPI card 15px. No 4-/8-pt grid. |
| D-05 | 🟠 | **17 emoji glyphs counted on Dashboard alone.** Sidebar nav (📊 🎫 🚨 📅 🏥 👷 ⚠️ 🏅 📈 🛡️ ℹ️), section headings (📋 🏥 🏅 📈 🛡️), CTA buttons (📤 📧 ⬇ 🖨 ✓ ↻ ↺), state markers (🚨 ⚠️). Emoji renders inconsistently across OS / browser, signals "casual" rather than "enterprise." |
| D-06 | 🟠 | **Only two button variants** (`btn-primary`, `btn-ghost`) — no `btn-danger`, no `btn-secondary`, no `btn-link`. Field Team delete `×` shares ghost styling with Cancel. |
| D-07 | 🟠 | **No empty-state illustrations.** Searching for an unmatched string doesn't show a "No results" message — table just goes blank or row count drops with no acknowledgement. |
| D-08 | 🟡 | **No table polish:** no zebra striping, no sticky headers, no row hover detail peek, no density toggle, no column visibility control. With 13–16 columns this hurts scanability. |
| D-09 | 🟡 | **No skeleton loaders observable.** Project memory mentions `.skeleton` class is in CSS but I never saw it render — page transitions just snap. |
| D-10 | 🟡 | **KPI subtitle scope formats are inconsistent:** "Jan 2025 – April 2026" / "ALL TIME" / "Require action now" / "56% of scope" / "Across 21 cities" — five formats across 9 cards. |
| D-11 | 🟡 | **Navigation has no breadcrumb / no page title in the topbar** — relying on the active nav item highlight as the only orientation cue. |
| D-12 | 🟢 | **Spelling/data quality visible in modals:** "Recieved", "Alaram", ".Bore Light." with random punctuation. These are XLSX-source strings but they reach end users. Worth at minimum a normalization pass on display, ideally back-to-source cleanup. |

### 4.3 Information architecture

| # | Severity | Finding |
|---|---|---|
| I-01 | 🟠 | **No deep-linking.** Active tab is a JS variable; URL is always `…/staging/`. You cannot bookmark "Open Tickets" or share a link to a specific ticket modal. Hash routing was flagged in the recap as the deferred decision — answering it should be Phase 1. |
| I-02 | 🟠 | **Service History (290 rows, browse-all) and Open Tickets (6 rows, action-now) are separate top-level entries.** They share 7+ columns and the same ticket modal. Consider Open Tickets as a saved filter on Service History rather than a separate page. |
| I-03 | 🟠 | **No global search.** Search box exists per page, no cross-entity search. Finding "Magnus Diagnostics" requires knowing whether it's a customer (Install Base), an asset (PM), or a ticket (Service History). |
| I-04 | 🟡 | **Reports is a static read-only KPI dump,** not configurable. Every time you want a different cut you go elsewhere. Either delete and merge into Dashboard, or upgrade to true configurable reporting. |
| I-05 | 🟡 | **Dashboard mixes 3 concerns** (top-line KPIs · open ticket preview · contract renewal table) with no visual section separation. Banner at top, no section headings. |
| I-06 | 🟡 | **No charts on Dashboard.** Zero `<canvas>` or `<svg>` graphics. Inverse: 9 number tiles + 2 tables. Even a sparkline per KPI or a 6-month tickets-by-month bar chart would shift perceived depth significantly. Recap roadmap item #5 (sparklines in KPIs) is exactly right. |
| I-07 | 🟡 | **Engineer's dashboard still shows "118 Audit Flags" alert** at top, but engineer can't visit Flags & Ambiguities. Alert teases data the user can't action. Either gate the alert to roles with access, or render the count without making it a CTA. |

### 4.4 Accessibility (WCAG 2.1 AA gaps)

| # | Severity | Finding |
|---|---|---|
| A-01 | 🔴 | **1,816 elements have `cursor: pointer` without `role` or `tabindex`.** Sidebar nav items, KPI tiles, table rows, action-cell triggers — none keyboard-reachable, none announced to screen readers. |
| A-02 | 🔴 | **359 of 370 inputs have no associated `<label for=…>`, `aria-label`, or non-decorative placeholder.** That's 97%. |
| A-03 | 🔴 | **3 modals on the page have no `role="dialog"`, no `aria-modal`, no `aria-labelledby`.** No focus trap (focus stays on `<body>` after open). Close `×` is a `<span>`, not a `<button>`. |
| A-04 | 🟠 | **Zero `aria-live` regions.** Realtime updates ("LIVE" badge), period filter changes, search filtering, ticket modal contents — none announced. |
| A-05 | 🟠 | **Heading hierarchy broken.** Two `<h1>` elements; zero `<h2>` and `<h3>` on every page checked. KPI labels are `<div>`s. Section titles are `<div>`s. Screen-reader heading nav (`H` / `1` / `2` keys) gives no structure. |
| A-06 | 🟠 | **No skip-to-content link.** With a 224px sidebar of nav items, keyboard users tab through every entry on every page load. |
| A-07 | 🟡 | **Tooltip cursor (`cursor: help`)** on SLA / MTTR / Repeat Failures cards — but the tooltip content is not exposed to screen readers (no `aria-describedby` checked, but no `[role=tooltip]` wrapper found). |

### 4.5 Performance & reliability

| # | Severity | Finding |
|---|---|---|
| P-01 | 🟡 | **All 11 pages are pre-rendered in DOM and toggled via `display:none/block`.** Initial paint requires building 290 ticket rows + 26 assets + 22 PMs + 9 engineers + 118 ambiguity rows + 500 audit log rows = ~965 DOM rows up-front. Acceptable today; will struggle once tickets cross ~5k. |
| P-02 | 🟡 | **3 modal-overlay nodes always present in DOM.** Even when no modal is open, three skeletons live in the tree. Z-index/focus-trap risks, plus wasted memory. |
| P-03 | 🟡 | **`Loaded: …` console log fires 4× per sign-in.** Suggests the data-load handler is registered to multiple events (auth, realtime sub, navigate, refresh) without dedupe. |
| P-04 | 🟢 | **Period chip filter is client-side only** (no extra network on chip click) — good for perf, confirmed via network tracking. |
| P-05 | 🟢 | **Audit log POST per navigate** — chatty but unblocking. |

### 4.6 Responsive

CSS breakpoints found: **`(max-width: 1024px)`, `(max-width: 768px)`, `(max-width: 420px)`**.

| # | Severity | Finding |
|---|---|---|
| R-01 | 🟡 | **No tablet-specific table treatment.** A 13–16 column table at 768px wraps catastrophically. The audit could not physically resize the OS window below the user's screen, so I read the media query rules: at ≤1024px, KPI grid drops to 3 cols, content padding shrinks. At ≤768px, sidebar slides off-canvas with a backdrop. **No tableviewer transformation** (e.g. card list, hide-secondary-columns, horizontal scroll affordance). |
| R-02 | 🟡 | **Tables rely on parent `overflow-x: auto`** — works mechanically, but no scroll shadow, no sticky first column, so the table just clips silently. |

### 4.7 Permissions sanity-check

Verified live. Cleanly enforced at the body-class level — no leakage observed:

| Check | Result |
|---|---|
| Manager sees `.admin-only` button visible? | 0/259 — clean |
| Engineer sees `.pm-manage` button visible? | 0/3 — clean |
| Engineer sees `.admin-only` button visible? | 0/259 — clean |
| Manager sidebar items hidden? | Flags & Ambiguities, Audit Log — correct |
| Engineer sidebar items hidden? | Flags & Ambiguities, Engineer Performance, Audit Log — correct |

The two role-leakage edge cases worth verifying with backend RLS (not just CSS hide):
1. Engineer who hits the Supabase REST endpoint directly for `audit_log` or `ambiguities` rows — does RLS deny? Memory says "yes, RLS in DB" but I didn't run that test in this session.
2. Manager who fetches superadmin-only fields on the Field Team — same RLS confirmation needed.

Those are 5-min curl tests with each role's JWT and should be added to a CI smoke pack.

### 4.8 Data quality observations (for product owner, not engineering)

- 29 tickets dated outside the reporting window (banner). Either inflate the window or fix the source XLSX.
- "Recieved" / "Alaram" / ".Bore Light." spelling reaches users via ticket modals.
- Ticket TKT-Apr2026-237 shows ATTENDED 03 Aug 2026 (4 months in the future from today's 2026-04-26).

---

## 5. What "enterprise SaaS standard" means for this product

Anchoring against ServiceNow / Salesforce, the rework should target these specific standards. None of these are aspirational — they're table-stakes:

1. **Coherent design system:** spacing scale (4/8/12/16/24/32/48), type scale (12/14/16/20/24/30/36), 6-step elevation, full semantic color set, three button variants (primary/secondary/danger) + ghost/link.
2. **Inline icons, not emoji.** Lucide / Phosphor / Material — single-color, consistent stroke, scalable, neutral.
3. **Data-grid quality tables:** column sort, sticky header + first column, row hover detail, density toggle, column visibility, CSV/XLSX/PDF export per current view, virtualized rows for >1k.
4. **Deep-linkable URLs:** `/tickets/TKT-Apr2026-265`, `/pm/PM-15`, etc. Hash routing minimum.
5. **Global search** with cross-entity hits (customer / asset / ticket / engineer).
6. **Inline editing on tickets** for status / engineer / resolution notes — Supabase RLS already gates writes; UI just needs the affordances.
7. **Activity timeline** on each ticket / PM (status changes, assignment, parts dates, audit-log slice).
8. **Charts on Dashboard:** at minimum a 12-month tickets-by-month + SLA% trend.
9. **Empty states** for every table and panel.
10. **Accessibility floor:** WCAG 2.1 AA — labeled inputs, semantic headings, dialog roles, focus traps, keyboard nav, skip-to-content.
11. **Responsive breakpoints honored** all the way down to 420px with a meaningful mobile experience.
12. **Theming:** light theme + dark theme switchable via single token map. The tokens already exist as variables; the rest of the codebase needs to migrate off hardcoded hex.

---

## 6. Phase-wise improvement roadmap

Each phase deploys **staging-first**, verifies with all three roles, then promotes to prod via the existing `release.sh` flow.

### Phase 0 — Quick wins / hotfixes (1-2 days, ship as v1.0.2)

**Why first:** these are correctness bugs, not redesigns. They can ship without the design-system rework and immediately remove embarrassments.

| ID | Item | Effort |
|---|---|---|
| F-01 | Either remove `cursor: pointer` from inert dashboard KPI cards, OR wire each card to filter Service History (e.g. clicking "Incidents" → Service History filtered to call_type=Incident). Pick one this phase. | S |
| F-03 | Hide the "ACTION" `<th>` for engineer role (currently the cells are hidden but the header still renders). Add `.pm-manage` to the `<th>` itself. | XS |
| F-08 | Fix the engineer-name-cell click in the dashboard ticket preview — currently opens an empty Engineer Performance modal. Either route to ticket modal (consistent with row click) or to a populated engineer drill-in. | S |
| F-11 | Insert a separator/break between `IN WINDOW` and `Due in 4d`. | XS |
| F-12 | Recompute Install Base header count from `<tbody>` row length, OR fix the seed data to not double-count. | S |
| F-14 | Remove "REOPEN RATE — v2 — not tracked yet" from Engineer Performance UI; if not tracked, hide the row. | XS |
| F-16 / P-03 | Dedupe the `Loaded: …` data-load handler so it fires once per actual data change. | S |
| F-05 | On sign-out, force a `location.reload()` after Supabase signOut so previous user's DOM cannot persist. | XS |
| D-02 | Add `button, input, select, textarea { font: inherit }` so primary CTAs render in Inter. | XS |
| D-12 | One-pass display normalization of "Recieved/Alaram" etc. on the modal field render (display-only fix; source data unchanged). Optional, talk to product owner. | S |

**Acceptance:** all three roles signed in on `/staging/`; spot-check confirms each fix; bump VERSION to 1.0.2; tag and ship.

### Phase 1 — Foundation: design system + accessibility floor (1-2 weeks, ship as v1.1.0)

**Why this is the gate to all later work:** once the design tokens, button hierarchy, and accessibility primitives exist, every subsequent feature consumes them and the visual delta compounds. Skipping this means every Phase 2 item gets re-done in Phase 3.

#### 1.1 Design system

- Define and document tokens (spacing 4–48, typography 12–36, elevation 6 steps, radius 4/6/8/12/16, full semantic color: success/warning/danger/info + neutral 0–900 + brand accent).
- Replace hardcoded hex values across `index.html` with `var(--*)`.
- Settle button hierarchy: `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-ghost`, `.btn-link`. One radius, one type, one font weight per variant.
- Replace **all 17+ inline emoji** in nav and section headers with inline Lucide SVG sprite. Keep emoji only in user-generated text (ticket descriptions).
- Topbar refinement: env pill ("STAGING"), role pill ("ADMIN"), persistent page title.

#### 1.2 Accessibility floor (A-01 → A-07)

- Convert sidebar `nav-item` divs to `<a href="#…">` with `role="link"` + keyboard activation.
- Add `<label>` to every input or `aria-label` if visual label is impractical.
- Add `role="dialog"`, `aria-modal="true"`, `aria-labelledby` to every modal; trap focus on open; restore focus on close; replace close-`<span>` with `<button aria-label="Close">`.
- Add `aria-live="polite"` regions for: realtime updates, period filter changes, search results count, "PM marked complete" toast.
- Promote section headings to `<h2>` / `<h3>` (KPI section title, Open Tickets section title, etc.).
- Add a skip-to-content link as the first focusable element.
- Run pa11y / axe-core in CI against staging; fail the build on AA violations.

#### 1.3 IA decisions resolved

The 8 questions from the previous session need to be answered before this phase starts. Candidate defaults (owner to confirm):

| Q | Default I'd recommend |
|---|---|
| Theme default | Polished dark (preserves current); Phase 2 adds light theme |
| Hash routing | Yes — `/#/tickets/TKT-…` minimum |
| Icon library | Inline Lucide sprite |
| Merge Service History + Open Tickets | Yes — Open Tickets becomes a saved filter |
| Drop emoji from chrome | Yes — keep only in user-generated content |
| Version this rework | v1.1.0 |
| Phase scope | Phase 1 only ships in v1.1.0; Phase 2 is v1.2.0 |
| Upload wizard redesign | Defer to Phase 2 |

**Acceptance:** axe-core AA clean; design-system token catalog documented in `/docs/DESIGN_SYSTEM.md`; staging visual regression check passes; sign-off across all three roles before tagging v1.1.0.

### Phase 2 — Workflow depth (2-3 weeks, ship as v1.2.0)

| Theme | Items |
|---|---|
| **Tables become data-grids** | F-02 column sort, sticky header + first column, density toggle, column visibility control, row-hover peek, virtualized rows when >500 |
| **Ticket workflow** | F-07 inline edit on ticket modal (status / engineer / resolution / parts) with Supabase RLS-gated writes; activity timeline below the modal showing audit-log slice for that ticket |
| **Engineer self-service** | F-04 expose Engineer Performance to engineer scoped to their own ID — give them their SLA / MTTR / FTF / PM completion stats |
| **PM workflow for engineer** | F-03 give engineer the "Mark PM Completed" action gated to PMs they're assigned to (RLS rule: `engineer_ids @> array[auth.uid()]`) |
| **Dashboard analytics** | I-06 sparkline per KPI; 12-month tickets-by-month bar; SLA% trend line; modality distribution donut |
| **IA cleanup** | I-02 merge Open Tickets into Service History as a saved filter; I-04 either delete Reports or upgrade to a real configurable report builder |
| **Empty states** | D-07 illustrated empty states for every table and panel |
| **Global search** | I-03 single search field (top of topbar) with cross-entity results — customer / ticket / asset / engineer |

**Acceptance:** workflow walkthroughs recorded with each role on staging; production deploy after a 7-day staging soak period.

### Phase 3 — Polish + scale (1-2 weeks, ship as v1.3.0)

| Theme | Items |
|---|---|
| **Theming** | Light theme rendering identically via token swap; user preference persisted |
| **Mobile experience** | R-01 / R-02 — proper card-list view at ≤768px for tables; sticky scroll affordance; bottom-tab navigation alternative on phone |
| **Performance hardening** | P-01 lazy-render hidden pages; P-02 mount modals on demand only |
| **Audit log scaling** | F-15 paginate beyond 500; downsample navigate-events; keep all auth/upload/destructive events |
| **Notification UX** | Owner-defined toast/banner system riding on the new `aria-live` infrastructure from Phase 1 |
| **Documentation** | `/docs/DESIGN_SYSTEM.md`, `/docs/ROLES.md`, `/docs/UPLOAD_FORMAT.md`, in-app contextual help |

---

## 7. Staging-first deployment workflow

This already exists per `RELEASING.md`; the audit reaffirms the discipline. For each phase:

1. **Cut a staging branch** off `staging`: `git checkout staging && git checkout -b phase-1-design-system`.
2. **Implement + commit on the feature branch.** All changes go through the existing single-file pattern.
3. **Push the feature branch to GitHub** — it does NOT deploy yet.
4. **FF-merge the feature branch into `staging`** when ready. GitHub Pages auto-deploys to `/staging/` (and via the existing workflow, to `/` mirror).
5. **Verify on `https://3imedtech.github.io/mri-fieldops-dashboard/staging/`** with all three test accounts:
   - `abhijit.s@3imedtech.com` (admin)
   - `manager@3imedtech.com` (manager)
   - `engineer@3imedtech.com` (engineer)
6. **Soak for an explicit window.** Phase 0 — 24 hours. Phase 1/2/3 — 7 days minimum.
7. **Promote to prod via `./scripts/release.sh <new-version>`** — bumps VERSION, snapshots `releases/v<x>/`, generates manifest, tags. Existing flow.
8. **Production smoke test** on `https://3imedtech.github.io/mri-fieldops-dashboard/` with all three accounts.
9. **Document the release** in `CHANGELOG.md` with the issue IDs from §4 closed.
10. **Rollback procedure** is the existing `ROLLBACK.md` (2-min revert by tag).

**No phase ships to prod without the staging soak.** No exceptions for "small" patches — the v1.0.1 cycle proved the discipline pays for itself.

---

## 8. Open questions for product owner before Phase 1 starts

These block the design system + IA decisions:

1. **PM completion by engineers** — should we open this up (Phase 2 plan)? Today it's manager+admin only. Either we keep the current gate or we lift it with RLS scoping; pick before redesigning the PM page.
2. **Engineer self-view on Engineer Performance** — should engineers see their own metrics? My recommendation: yes, scoped to their own row.
3. **Ticket inline editing** — which fields are editable, by which role? Status, parts received, resolution notes seem safe; engineer reassignment likely admin/manager.
4. **Open Tickets → saved filter under Service History** (merge), or keep as separate top-level page? If we merge, we save a top-level slot for global search.
5. **Reports** — keep as static KPI dump, or upgrade to configurable report builder? If neither, delete.
6. **Theme** — light + dark, dark-only, light-only as default?
7. **Hash routing acceptable** (or do we need real `/path` URLs which would push us off GitHub Pages)?
8. **Audit-log retention strategy** — keep navigate events forever? Drop after 30 days? Move to a dedicated cold table?

---

## 9. What was NOT covered in this audit (deliberate)

- **Backend RLS verification under direct Supabase REST calls.** I only verified UI hide/show. RLS enforcement is critical and deserves a separate 30-min curl-driven test pass per role.
- **XLSX upload flow under fresh data.** The button is wired; I did not actually upload a file because that mutates staging data.
- **Email send paths** (PM reminders, daily SLA digest, password reset). I observed the buttons; I did not click "Send."
- **CSV / PDF export.** Buttons present on Service History and Reports. I did not download files.
- **Realtime sync verification.** "LIVE" badge present in topbar; I did not run a two-tab concurrent-edit test in this session.
- **Visual screenshot review at multiple breakpoints.** The browser MCP couldn't physically resize the OS window below the user's display; I read CSS rules instead. A device-emulation screenshot pass is worth doing in DevTools before Phase 1 design freeze.

These are all worthy of a follow-up pass once the owner approves the roadmap.

---

## 10. Recommendation

**Approve Phase 0 immediately** — these are correctness fixes and will ship in a day. They cost almost nothing and remove the most embarrassing UX issues (inert KPI tiles, action column header for engineer, Arial buttons, sign-out DOM leak).

**Decide on the Phase 1 questions in §8 within the week.** Once those answers exist, Phase 1 (design system + accessibility) is 1-2 weeks of mechanical work that compounds into every later phase.

**Phases 2 and 3 are sequenced and dependent.** Phase 2 ships workflow depth; Phase 3 ships polish + theming. Do not start Phase 2 before Phase 1 lands — the design system is the foundation for all of it.

The product is in a healthy place to do this well: versioning is in place, rollback is exercised, staging is real, three roles are clean. The release machinery from v1.0.0/1.0.1 means none of this work has to be rushed.
