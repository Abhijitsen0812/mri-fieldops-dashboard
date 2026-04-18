// ─────────────────────────────────────────────────────────────────────
// MRI FieldOps — Daily SLA + PM alerts
//
// Runs on a cron from GitHub Actions. Queries Supabase for:
//   1. Tickets with status = 'Open' whose call_date is older than
//      SLA_BREACH_DAYS (default 3) and that have no attended_date
//      recorded yet.
//   2. PMs (pm_schedule) whose next_pms is in the past and whose
//      status is neither 'completed' nor 'closed' (normalised).
//
// Sends a single digest email via Zoho SMTP. If both lists are empty,
// no email is sent (to avoid alert fatigue).
//
// Env vars (set as GitHub Actions secrets):
//   SUPABASE_URL                 https://<ref>.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY    service_role JWT (bypasses RLS)
//   ZOHO_SMTP_HOST               default: smtp.zoho.in
//   ZOHO_SMTP_PORT               default: 465 (SSL)
//   ZOHO_SMTP_USER               sender login (full email)
//   ZOHO_SMTP_PASS               Zoho App-Password (NOT regular pw)
//   ALERT_FROM                   "Name <email@domain>" or plain email
//   ALERT_TO                     comma-separated recipients
//   SLA_BREACH_DAYS              default: 3
//   DRY_RUN                      if "true", print and don't send
// ─────────────────────────────────────────────────────────────────────

import nodemailer from 'nodemailer';

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  ZOHO_SMTP_HOST = 'smtp.zoho.in',
  ZOHO_SMTP_PORT = '465',
  ZOHO_SMTP_USER,
  ZOHO_SMTP_PASS,
  ALERT_FROM,
  ALERT_TO,
  SLA_BREACH_DAYS = '3',
  DRY_RUN = 'false',
} = process.env;

function requireEnv(name, val){
  if(!val || !String(val).trim()){
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
}

requireEnv('SUPABASE_URL', SUPABASE_URL);
requireEnv('SUPABASE_SERVICE_ROLE_KEY', SUPABASE_SERVICE_ROLE_KEY);

const isDryRun = String(DRY_RUN).toLowerCase() === 'true';
if(!isDryRun){
  requireEnv('ZOHO_SMTP_USER', ZOHO_SMTP_USER);
  requireEnv('ZOHO_SMTP_PASS', ZOHO_SMTP_PASS);
  requireEnv('ALERT_FROM', ALERT_FROM);
  requireEnv('ALERT_TO', ALERT_TO);
}

const breachDays = Math.max(1, parseInt(SLA_BREACH_DAYS, 10) || 3);

// ── Supabase REST helper ──────────────────────────────────────────────
async function sbSelect(table, query){
  const url = `${SUPABASE_URL}/rest/v1/${table}?${query}`;
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Accept-Profile': 'public',
    },
  });
  if(!res.ok){
    const body = await res.text();
    throw new Error(`Supabase query failed (${res.status}) for ${table}: ${body}`);
  }
  return res.json();
}

// ── Date helpers (all in UTC, dates only) ─────────────────────────────
function todayUTCDate(){
  const d = new Date();
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}
function isoDate(d){ return d.toISOString().slice(0, 10); }
function daysBetween(a, b){
  return Math.round((b - a) / 86400000);
}
function parseSqlDate(s){
  if(!s) return null;
  // Accept 'YYYY-MM-DD' or ISO timestamps
  const t = String(s).slice(0, 10);
  const [y, m, day] = t.split('-').map(Number);
  if(!y || !m || !day) return null;
  return new Date(Date.UTC(y, m - 1, day));
}

// ── Queries ───────────────────────────────────────────────────────────
async function getSlaBreaches(){
  const today = todayUTCDate();
  const cutoff = new Date(today.getTime() - breachDays * 86400000);
  // PostgREST:
  //   status=ilike.*open*  → matches 'Open', 'OPEN', 'Re-Open', etc.
  //   call_date=lt.<cutoff>
  //   attended_date=is.null
  const params = new URLSearchParams({
    select: 'id,customer,model,town,state,issue,call_date,engineer,parts,status',
    status: 'ilike.*open*',
    call_date: `lt.${isoDate(cutoff)}`,
    attended_date: 'is.null',
    order: 'call_date.asc',
    limit: '500',
  });
  const rows = await sbSelect('tickets', params.toString());
  // Annotate with age in days
  return rows.map(r => {
    const cd = parseSqlDate(r.call_date);
    return {
      ...r,
      age_days: cd ? daysBetween(cd, today) : null,
    };
  });
}

async function getOverduePMs(){
  const today = todayUTCDate();
  const params = new URLSearchParams({
    select: 'id,customer,model,town,region,contract,freq,last_pms,next_pms,status',
    next_pms: `lt.${isoDate(today)}`,
    // Exclude closed/completed/cancelled states
    status: 'not.in.(completed,closed,cancelled,not-covered,installation-pending)',
    order: 'next_pms.asc',
    limit: '500',
  });
  const rows = await sbSelect('pm_schedule', params.toString());
  return rows.map(r => {
    const nd = parseSqlDate(r.next_pms);
    return {
      ...r,
      days_overdue: nd ? daysBetween(nd, today) : null,
    };
  });
}

// ── HTML rendering ────────────────────────────────────────────────────
function esc(s){
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderSlaTable(rows){
  if(rows.length === 0){
    return `<p style="margin:4px 0 16px;color:#2a7a2a"><strong>No SLA breaches.</strong> All open tickets are within the ${breachDays}-day window.</p>`;
  }
  const tr = rows.map(r => `
    <tr>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-family:monospace;font-size:11px">${esc(r.id)}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5">${esc(r.customer || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-size:12px;color:#555">${esc(r.model || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-family:monospace;font-size:11px">${esc(r.call_date || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;text-align:right;font-weight:600;color:${r.age_days >= 7 ? '#c0392b' : '#e67e22'}">${r.age_days ?? '—'}d</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-size:12px">${esc(r.engineer || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-size:12px;max-width:260px">${esc((r.issue || '').slice(0, 120))}</td>
    </tr>`).join('');
  return `
    <h3 style="margin:16px 0 6px;color:#c0392b">⚠️ SLA Breach — ${rows.length} open ticket${rows.length === 1 ? '' : 's'} &gt; ${breachDays}d</h3>
    <table style="border-collapse:collapse;width:100%;font-size:13px;font-family:-apple-system,Segoe UI,sans-serif">
      <thead>
        <tr style="background:#fdecea">
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">TICKET</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">CUSTOMER</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">MODEL</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">CALL DATE</th>
          <th style="padding:8px 10px;text-align:right;font-size:11px;letter-spacing:.5px">AGE</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">ENGINEER</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">ISSUE</th>
        </tr>
      </thead>
      <tbody>${tr}</tbody>
    </table>`;
}

function renderPMTable(rows){
  if(rows.length === 0){
    return `<p style="margin:4px 0 16px;color:#2a7a2a"><strong>No PMs overdue.</strong> All preventive maintenance is current.</p>`;
  }
  const tr = rows.map(r => `
    <tr>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-family:monospace;font-size:11px">${esc(r.id)}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5">${esc(r.customer || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-size:12px;color:#555">${esc(r.model || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-size:12px">${esc(r.town || '—')} · ${esc(r.region || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-family:monospace;font-size:11px">${esc(r.next_pms || '—')}</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;text-align:right;font-weight:600;color:${r.days_overdue >= 30 ? '#c0392b' : '#e67e22'}">+${r.days_overdue ?? '—'}d</td>
      <td style="padding:6px 10px;border-bottom:1px solid #e5e5e5;font-size:12px">${esc(r.contract || '—')}</td>
    </tr>`).join('');
  return `
    <h3 style="margin:20px 0 6px;color:#b26a00">🗓 PM Overdue — ${rows.length} machine${rows.length === 1 ? '' : 's'}</h3>
    <table style="border-collapse:collapse;width:100%;font-size:13px;font-family:-apple-system,Segoe UI,sans-serif">
      <thead>
        <tr style="background:#fff4e0">
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">PM ID</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">CUSTOMER</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">MODEL</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">LOCATION</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">NEXT DUE</th>
          <th style="padding:8px 10px;text-align:right;font-size:11px;letter-spacing:.5px">OVERDUE</th>
          <th style="padding:8px 10px;text-align:left;font-size:11px;letter-spacing:.5px">CONTRACT</th>
        </tr>
      </thead>
      <tbody>${tr}</tbody>
    </table>`;
}

function renderEmail(slaRows, pmRows){
  const today = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' });
  const subjectBits = [];
  if(slaRows.length) subjectBits.push(`${slaRows.length} SLA breach${slaRows.length === 1 ? '' : 'es'}`);
  if(pmRows.length)  subjectBits.push(`${pmRows.length} PM overdue`);
  const subject = subjectBits.length
    ? `[FieldOps] ${subjectBits.join(', ')} — ${today}`
    : `[FieldOps] All clear — ${today}`;

  const html = `<!doctype html>
<html><body style="margin:0;padding:20px;font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#222;background:#fafafa">
  <div style="max-width:900px;margin:0 auto;background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:24px">
    <div style="border-bottom:2px solid #2c3e50;padding-bottom:12px;margin-bottom:16px">
      <div style="font-size:18px;font-weight:700">MRI FieldOps — Daily Digest</div>
      <div style="font-size:12px;color:#666">3i MEDTECH · ${esc(today)}</div>
    </div>
    ${renderSlaTable(slaRows)}
    ${renderPMTable(pmRows)}
    <div style="margin-top:24px;padding-top:12px;border-top:1px solid #e5e5e5;font-size:11px;color:#888">
      Generated automatically by the FieldOps GitHub Actions cron (09:00 IST daily).<br>
      Dashboard: <a href="https://3imedtech.github.io/mri-fieldops-dashboard/" style="color:#2c3e50">3imedtech.github.io/mri-fieldops-dashboard</a>
    </div>
  </div>
</body></html>`;

  // Plain-text fallback
  const lines = [];
  lines.push(`MRI FieldOps — Daily Digest (${today})`);
  lines.push('');
  if(slaRows.length === 0){
    lines.push(`No SLA breaches. All open tickets within ${breachDays}-day window.`);
  } else {
    lines.push(`SLA BREACH — ${slaRows.length} open ticket(s) > ${breachDays}d:`);
    slaRows.forEach(r => {
      lines.push(`  · ${r.id}  ${r.customer}  (${r.model || '—'})  ${r.age_days}d old  — ${r.issue || ''}`.trim());
    });
  }
  lines.push('');
  if(pmRows.length === 0){
    lines.push('No PMs overdue.');
  } else {
    lines.push(`PM OVERDUE — ${pmRows.length} machine(s):`);
    pmRows.forEach(r => {
      lines.push(`  · ${r.id}  ${r.customer}  (${r.model || '—'})  due ${r.next_pms}  +${r.days_overdue}d`);
    });
  }
  lines.push('');
  lines.push('Dashboard: https://3imedtech.github.io/mri-fieldops-dashboard/');
  const text = lines.join('\n');

  return { subject, html, text };
}

// ── Main ──────────────────────────────────────────────────────────────
(async () => {
  try {
    console.log(`[fieldops-alerts] Querying Supabase for SLA breaches (>${breachDays}d) and overdue PMs…`);
    const [slaRows, pmRows] = await Promise.all([getSlaBreaches(), getOverduePMs()]);
    console.log(`[fieldops-alerts] Found ${slaRows.length} SLA breaches, ${pmRows.length} overdue PMs.`);

    if(slaRows.length === 0 && pmRows.length === 0){
      console.log('[fieldops-alerts] Both lists are empty — skipping email send to avoid alert fatigue.');
      return;
    }

    const { subject, html, text } = renderEmail(slaRows, pmRows);

    if(isDryRun){
      console.log('[fieldops-alerts] DRY_RUN=true — printing digest instead of sending:');
      console.log('---- SUBJECT ----');
      console.log(subject);
      console.log('---- TEXT ----');
      console.log(text);
      return;
    }

    const port = parseInt(ZOHO_SMTP_PORT, 10) || 465;
    const transporter = nodemailer.createTransport({
      host: ZOHO_SMTP_HOST,
      port,
      secure: port === 465, // true for 465 (SSL), false for 587 (STARTTLS)
      auth: {
        user: ZOHO_SMTP_USER,
        pass: ZOHO_SMTP_PASS,
      },
    });

    const info = await transporter.sendMail({
      from: ALERT_FROM,
      to: ALERT_TO,
      subject,
      text,
      html,
    });
    console.log(`[fieldops-alerts] Email sent: ${info.messageId}`);
  } catch(err){
    console.error('[fieldops-alerts] FAILED:', err);
    process.exit(1);
  }
})();
