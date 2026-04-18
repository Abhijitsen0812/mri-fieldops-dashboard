# Daily SLA + PM alerts

A GitHub Actions cron that runs at **09:00 IST every day**, queries
Supabase for SLA breaches and overdue PMs, and emails a single digest
via Zoho SMTP.

## What it checks

| Rule | Query |
| --- | --- |
| **SLA breach** | `tickets.status ILIKE '%open%'` AND `call_date < today − 3 days` AND `attended_date IS NULL` |
| **PM overdue** | `pm_schedule.next_pms < today` AND `status NOT IN ('completed', 'closed', 'cancelled', 'not-covered', 'installation-pending')` |

If both lists are empty, no email is sent (to avoid alert fatigue).

## One-time setup

### 1. Generate a Zoho App Password

Zoho's SMTP does **not** accept your normal account password — you need
an app-specific one.

1. Sign in at <https://accounts.zoho.in/> (or `.com` if you're on the
   US data centre).
2. **Security → App Passwords → Generate New Password**.
3. Label it `FieldOps Alerts`, click **Generate**, copy the password
   (shown only once).

### 2. Get the Supabase service-role key

1. Supabase Dashboard → **Project Settings → API**.
2. Under **Project API keys**, copy the **`service_role`** key
   (the long one labelled *secret*, NOT `anon`). This bypasses RLS so
   the cron can read tickets without a logged-in user.

### 3. Add GitHub secrets

Repo → **Settings → Secrets and variables → Actions → New repository
secret**. Add each of the following:

| Secret name | Value |
| --- | --- |
| `SUPABASE_URL` | `https://mvwhubatooliudbvythy.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | *(the service_role key from step 2)* |
| `ZOHO_SMTP_HOST` | `smtp.zoho.in` *(or `smtp.zoho.com` for US)* |
| `ZOHO_SMTP_PORT` | `465` |
| `ZOHO_SMTP_USER` | your full Zoho login email, e.g. `abhijit.s@3imedtech.com` |
| `ZOHO_SMTP_PASS` | the App Password from step 1 |
| `ALERT_FROM` | `FieldOps Alerts <abhijit.s@3imedtech.com>` *(must match the Zoho account)* |
| `ALERT_TO` | comma-separated list, e.g. `abhijit.s@3imedtech.com,manager@3imedtech.com` |

### 4. Test it

1. Repo → **Actions → Daily SLA + PM alerts → Run workflow**.
2. Optional: set `dry_run = true` to print the digest in the logs
   without sending an email.
3. Live run: leave `dry_run` blank. Check your inbox within ~30 s.

The cron fires automatically at 03:30 UTC (09:00 IST) daily.

## Changing thresholds

- **SLA window**: edit `SLA_BREACH_DAYS` in
  `.github/workflows/daily-alerts.yml` (default `"3"`).
- **Cadence**: edit the `cron:` expression in the same file
  (default `'30 3 * * *'` — 03:30 UTC daily).
- **Subject line / formatting**: edit `renderEmail()` in
  `daily-alerts.mjs`.

## Local testing

```bash
cd scripts
npm install
DRY_RUN=true \
SUPABASE_URL=https://mvwhubatooliudbvythy.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<key> \
  node daily-alerts.mjs
```
