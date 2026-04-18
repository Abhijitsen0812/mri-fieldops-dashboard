# Restoring a database backup

The `Daily DB backup` GitHub Action writes an encrypted artifact every
day:

```
fieldops-backup-YYYYMMDDTHHMMSSZ.sql.gz.enc
```

It's encrypted with `AES-256-CBC` (PBKDF2, 100k iterations, random
salt) using the `BACKUP_ENCRYPTION_KEY` secret. Anyone with read
access to the repo can *download* the ciphertext from the Actions
tab, but it's useless without the key.

## 1. Download the artifact

1. Repo → **Actions → Daily DB backup**.
2. Click the run you want (each row shows its date).
3. Scroll to **Artifacts** at the bottom → click the filename to
   download a zip.
4. Unzip it — inside is the `.sql.gz.enc` file.

## 2. Decrypt + decompress to plain SQL

On any machine with `openssl` and `gzip` installed (macOS, Linux,
or WSL):

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass pass:"$BACKUP_ENCRYPTION_KEY" \
  -in  fieldops-backup-YYYYMMDDTHHMMSSZ.sql.gz.enc \
  -out fieldops-backup.sql.gz

gunzip fieldops-backup.sql.gz
# → fieldops-backup.sql  (plain SQL, ready to apply)
```

> Replace `$BACKUP_ENCRYPTION_KEY` with the same passphrase you set
> in GitHub Secrets. Do **not** commit or share this value.

If `openssl` prints `bad decrypt`, the passphrase is wrong.

## 3. Restore into a Postgres database

### Option A — restore into a **new** Supabase project (recommended for disaster recovery)

1. Supabase Dashboard → **New project**.
2. Wait for it to provision.
3. Get the new **Direct** connection string
   (Project Settings → Database → Connection string → URI → Direct).
4. Apply:
   ```bash
   psql "postgres://postgres:<password>@db.<new_ref>.supabase.co:5432/postgres" \
     < fieldops-backup.sql
   ```
5. Update `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `index.html` to
   point at the new project, redeploy, and tell the team to log in
   again (auth state lives in the old project and is not migrated).

### Option B — restore **over** the current project

⚠️ This *wipes and replaces* the `public` schema. Never do this
without confirmation.

```bash
psql "$SUPABASE_DB_URL" < fieldops-backup.sql
```

The dump was taken with `--clean --if-exists`, so it drops tables
before recreating them.

## 4. Verify

After restoring, spot-check a few rows:

```bash
psql "$DB_URL" -c "SELECT count(*) FROM tickets;"
psql "$DB_URL" -c "SELECT count(*) FROM pm_schedule;"
psql "$DB_URL" -c "SELECT count(*) FROM engineers;"
```

## What the backup does NOT include

- **`auth.users`** (the user accounts themselves). Supabase manages
  this schema with internal triggers that conflict with `pg_dump`
  output. If you need to migrate users to a new project, recreate
  them in the Auth → Users UI — passwords can't be migrated, so each
  user will need to go through "Forgot password?" on the new
  deployment.
- **Supabase Storage objects** (no file attachments yet, so N/A).
- **Rate-limit state, rolling audit log truncation, etc.** — these
  are ephemeral.

## Testing the backup without a real disaster

A restore drill every 3 months is good hygiene:

1. Download the latest artifact.
2. Decrypt it.
3. `head -100 fieldops-backup.sql` — confirms it's a valid PG dump
   starting with `-- PostgreSQL database dump`.
4. Optionally apply it to a local Docker Postgres and run the count
   queries above.

If decryption ever fails, **rotate `BACKUP_ENCRYPTION_KEY`
immediately** and re-run the workflow to produce a fresh artifact.
