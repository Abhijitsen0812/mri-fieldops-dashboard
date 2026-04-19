# MRI FieldOps Dashboard — Deployment Guide

Going from the single HTML file to a live, team-accessible app on the internet. Budget: ~90 minutes first time, ~5 minutes for subsequent updates.

**What you'll end up with:**
- A public URL like `https://yourname.github.io/mri-fieldops/`
- A login screen (email + password)
- A Supabase database holding all tickets, engineers, PMs, etc.
- Five team members able to view and edit simultaneously
- Automatic deployment when you update the HTML file on GitHub

**What you won't have (yet):**
- Real-time updates (changes show up on other users' screens only when they refresh)
- Granular role-based permissions (all logged-in users are editors)
- Custom domain (free `*.github.io` subdomain only)

---

## Part A — Supabase (30 min)

### A.1 Create account & project

1. Go to **https://supabase.com** and click **Start your project** (top right).
2. Sign up with GitHub (easiest) or email.
3. Click **New project**.
   - **Name**: `mri-fieldops` (or anything).
   - **Database Password**: click the Generate button, then **save this password somewhere safe** (1Password, a text file, whatever). You won't need it daily, but you'll need it to run the occasional database migration.
   - **Region**: pick the one nearest India — `Mumbai (ap-south-1)` or `Singapore (ap-southeast-1)`.
   - **Plan**: Free.
4. Click **Create new project** and wait ~2 minutes while it provisions.

### A.2 Run the schema SQL

1. In the left sidebar, click the **SQL Editor** icon (looks like `</>`).
2. Click **New query**.
3. Open `01_schema.sql` (provided alongside this guide), copy the entire contents, paste into the SQL editor.
4. Click **Run** (bottom right, or Ctrl/Cmd+Enter).
5. Expected output: "Success. No rows returned." If you see errors, **stop and send me the full error text** — don't proceed.

### A.3 Run the seed SQL

1. Click **New query** again.
2. Open `02_seed_data.sql`, copy all, paste, click **Run**.
3. Expected: "Success. No rows returned." (The script is idempotent — running twice is fine, it truncates before inserting.)
4. Verify: click **Table Editor** in the left sidebar. You should see `engineers` (9 rows), `tickets` (143 rows), `config_assets` (25 rows), `pm_schedule` (22 rows), `ambiguities` (13 rows), `cmc_contracts` (4 rows).

### A.4 Get your credentials

1. Left sidebar → **Project Settings** (gear icon at the bottom) → **API**.
2. Copy two values to a temporary notepad:
   - **Project URL** — looks like `https://abcdefghij.supabase.co`
   - **anon public** key — a long string starting with `eyJhb…`

   ⚠️ These two values are safe to put in your HTML (they're designed to be public). The **service_role** key on the same page is NOT safe — never use that in the dashboard.

### A.5 Create user accounts

1. Left sidebar → **Authentication** → **Users** tab.
2. Click **Add user** → **Create new user**.
3. Enter email (e.g. your own) and a password, then **uncheck** "Auto Confirm User" if you want to verify via email, or leave it checked for instant activation (recommended for internal use).
4. Click **Create user**.
5. Repeat for each team member (max 5 for now).

---

## Part B — GitHub (20 min)

### B.1 Create GitHub account (skip if you have one)

1. **https://github.com/signup** — free plan is fine.
2. Verify your email.

### B.2 Create the repo

1. Top right → **+** → **New repository**.
2. **Repository name**: `mri-fieldops-dashboard` (dashes, no spaces).
3. **Public** or **Private** — both work with GitHub Pages on the free plan these days. Private is safer for your data even though the data lives in Supabase.
4. Check **Add a README file**.
5. Click **Create repository**.

### B.3 Upload the dashboard file

1. On the repo page, click **Add file** → **Upload files**.
2. Drag `MRI_FieldOps_Dashboard_v11.html` into the browser.
3. **Rename it to `index.html`** — GitHub Pages looks for this name by default. You can do the rename on your computer before upload, or click the filename after upload to rename inline.
4. Commit message: "Initial deploy", click **Commit changes**.

### B.4 Turn on GitHub Pages

1. In the repo, click **Settings** (top right of repo menu).
2. Left sidebar → **Pages**.
3. Under **Build and deployment**:
   - **Source**: `Deploy from a branch`
   - **Branch**: `main`, folder `/ (root)`.
   - Click **Save**.
4. Wait 1-2 minutes. Refresh the Pages settings — you should see a green box with:
   > Your site is live at `https://YOUR_USERNAME.github.io/mri-fieldops-dashboard/`
5. Open that URL. You should see the login screen.

### B.5 Configure Supabase credentials

Open `index.html` in the GitHub web editor (click the file, click the pencil icon).

Find this block near the top of the `<script>` section:

```js
const SUPABASE_URL     = 'REPLACE_WITH_YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'REPLACE_WITH_YOUR_ANON_KEY';
```

Replace both strings with the values from step A.4. Click **Commit changes**.

Wait 60 seconds (GitHub redeploys), refresh your site URL. Log in with one of the users you created in A.5.

---

## Part C — Day-to-day updates

### Updating the dashboard code

1. Edit `index.html` in GitHub's web editor (or use git locally if you're comfortable).
2. Commit.
3. Wait ~60 seconds. Your live site auto-updates.

### Adding a new team member

Supabase → Authentication → Users → Add user. No code change needed.

### Viewing your data

Supabase → Table Editor → pick a table. You can edit rows directly here — useful for quick fixes.

### Backing up

Supabase free tier includes daily backups for 7 days. For longer retention:
- Database → Backups → **Download backup** (manual, once a week is enough).
- Or Settings → Database → **Connection String** and use `pg_dump` from your computer.

---

## Part D — Troubleshooting

**"Invalid login credentials"**
- Check the user exists in Auth → Users.
- Reset the password from that screen.

**"Failed to load" / tickets don't appear after login**
- Open browser DevTools (F12) → Console tab. Look for red errors.
- Most common: typo in `SUPABASE_URL` or `SUPABASE_ANON_KEY`.
- Second most common: RLS policies not applied — re-run the bottom section of `01_schema.sql`.

**Row-level security denies my writes**
- The policies in `01_schema.sql` allow any authenticated user to read/write.
- If you tightened them later and got locked out, re-run that section.

**The page is blank**
- View source. If you see raw HTML with no rendering, your GitHub Pages is still building. Wait 2 minutes.
- Check Settings → Pages that the green "site is live" banner appears.

**I want a custom domain**
- Buy a domain from Namecheap / Google Domains / etc.
- In GitHub: Settings → Pages → Custom domain → enter `fieldops.3imedtech.com` → Save.
- At your domain registrar: add a CNAME record pointing `fieldops` to `YOUR_USERNAME.github.io`.
- Wait for DNS propagation (a few minutes to a few hours).

---

## Part E — What's running where

```
┌─ Your browser ─────────────────────┐
│                                    │
│  index.html (loaded from GitHub)   │
│       │                            │
│       ▼ HTTPS                      │
│                                    │
└────────┬───────────────────────────┘
         │
         │ REST API calls with JWT token
         │ (token from login)
         ▼
┌─ Supabase (cloud) ─────────────────┐
│                                    │
│  Postgres DB                       │
│  • tickets, engineers, pms, etc.   │
│  Auth service                      │
│  • email/password login            │
│  Row-Level Security                │
│  • blocks anonymous access         │
│                                    │
└────────────────────────────────────┘
```

No server of your own. No backend code to maintain. All data flows straight from your browser to Supabase, validated by RLS policies.

---

## Part F — Cost

**Year 1: $0**
- Supabase free tier: 500 MB DB, 50K monthly active users, 5 GB egress. You'll use ~5 MB and a few KB egress per month.
- GitHub Pages: free for public repos; free for private repos on any paid GitHub plan. If you keep the repo public, $0.
- Your dataset is 100× smaller than the free tier limits, so there's no realistic path to overage unless you add hundreds of engineers and millions of tickets.

**If you outgrow free:**
- Supabase Pro: $25/month. 8 GB DB, 250 GB egress, daily backups for 14 days.
- That's the next step, not a $500/month enterprise plan.
