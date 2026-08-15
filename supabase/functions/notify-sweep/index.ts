// path: supabase/functions/notify-sweep/index.ts
// Scheduled sweep for time-based notification triggers that no user action can
// raise: `capa.overdue` and `inspection.due`. Closes the deferred cron item from
// Prompt 15 (Ledger sections 11/12).
//
// Called by pg_cron via pg_net (see migration 0017), NOT by the app. It therefore
// has no user JWT: deploy with `--no-verify-jwt` and authorise with the shared
// secret `SWEEP_SECRET` instead. Everything it does runs as service role, which
// is why the secret is the only gate.
//
// Deploy: `supabase functions deploy notify-sweep --no-verify-jwt`

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { fcmConfigured, sendPush } from '../_shared/fcm.ts';

const URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SWEEP_SECRET = Deno.env.get('SWEEP_SECRET');
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { 'Content-Type': 'application/json' } });

interface Job {
  trigger: 'capa_overdue' | 'inspection_due';
  entityType: string;
  entityId: string;
  companyId: string;
  recipientId: string;
  title: string;
  body: string;
  priority: string;
}

serve(async (req) => {
  // The only gate. Without it this endpoint is unauthenticated: it runs as
  // service role and would let anyone trigger a company-wide notification run.
  if (!SWEEP_SECRET || req.headers.get('x-sweep-secret') !== SWEEP_SECRET) {
    return json({ error: 'Forbidden' }, 403);
  }

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  // Dates are stored as `date`, so compare on a plain UTC day. A site whose
  // local day differs from UTC may see a notification shift by a few hours;
  // acceptable for a daily sweep, and noted in docs/15.
  const today = new Date().toISOString().slice(0, 10);

  // --- overdue CAPAs -------------------------------------------------------
  // Ledger section 10: overdue starts the day AFTER the due date, so `due_date <
  // today` -- a CAPA due today is not yet overdue. Owner-only by decision; a
  // CAPA with no owner has nobody to chase and is skipped (it is still visible
  // on the dashboard's overdue KPI).
  const { data: capas, error: capaErr } = await admin
    .from('corrective_actions')
    .select('id, company_id, owner_id, description, due_date')
    .lt('due_date', today)
    .neq('status', 'closed')
    .not('owner_id', 'is', null);
  if (capaErr) console.error('sweep: CAPA query failed', capaErr);

  // --- due inspections -----------------------------------------------------
  // Due once the scheduled date arrives and until it leaves the working
  // statuses; submitted/closed inspections need no chasing.
  const { data: inspections, error: inspErr } = await admin
    .from('inspections')
    .select('id, company_id, inspector_id, scheduled_date, inspection_type')
    .lte('scheduled_date', today)
    .in('status', ['draft', 'in_progress']);
  if (inspErr) console.error('sweep: inspection query failed', inspErr);

  // --- idempotency ---------------------------------------------------------
  // At most one notification per entity per trigger per calendar day. Without
  // this a daily sweep would re-notify the same overdue CAPA indefinitely.
  const { data: sentToday } = await admin
    .from('notifications')
    .select('entity_id, trigger_type')
    .gte('created_at', `${today}T00:00:00Z`)
    .in('trigger_type', ['capa_overdue', 'inspection_due']);
  const already = new Set((sentToday ?? []).map((n: { trigger_type: string; entity_id: string }) =>
    `${n.trigger_type}:${n.entity_id}`));

  const jobs: Job[] = [];

  for (const c of (capas ?? []) as Array<Record<string, string>>) {
    if (already.has(`capa_overdue:${c.id}`)) continue;
    jobs.push({
      trigger: 'capa_overdue',
      entityType: 'corrective_action',
      entityId: c.id,
      companyId: c.company_id,
      recipientId: c.owner_id,
      title: 'CAPA overdue',
      body: `Due ${c.due_date}: ${(c.description ?? '').slice(0, 120)}`,
      priority: 'high',
    });
  }

  for (const i of (inspections ?? []) as Array<Record<string, string>>) {
    if (already.has(`inspection_due:${i.id}`)) continue;
    if (!i.inspector_id) continue;
    jobs.push({
      trigger: 'inspection_due',
      entityType: 'inspection',
      entityId: i.id,
      companyId: i.company_id,
      recipientId: i.inspector_id,
      title: 'Inspection due',
      body: `${(i.inspection_type ?? 'Inspection').replace('_', ' ')} scheduled for ${i.scheduled_date}`,
      priority: 'normal',
    });
  }

  if (jobs.length === 0) return json({ ok: true, delivered: 0, pushed: 0 });

  // In-app rows first: they are the guaranteed channel, and writing them before
  // pushing means a push failure cannot lose the notification.
  const { error: insertErr } = await admin.from('notifications').insert(jobs.map((j) => ({
    company_id: j.companyId,
    recipient_id: j.recipientId,
    trigger_type: j.trigger,
    priority: j.priority,
    title: j.title,
    body: j.body,
    entity_type: j.entityType,
    entity_id: j.entityId,
  })));
  if (insertErr) {
    console.error('sweep: notification insert failed', insertErr);
    return json({ error: 'insert failed' }, 500);
  }

  // --- push (best-effort) --------------------------------------------------
  let pushed = 0;
  if (fcmConfigured) {
    const recipients = [...new Set(jobs.map((j) => j.recipientId))];
    const { data: tokens } = await admin
      .from('device_tokens').select('id, token, user_id').in('user_id', recipients).eq('is_active', true);

    const byUser = new Map<string, Array<{ id: string; token: string }>>();
    for (const t of (tokens ?? []) as Array<{ id: string; token: string; user_id: string }>) {
      const list = byUser.get(t.user_id) ?? [];
      list.push({ id: t.id, token: t.token });
      byUser.set(t.user_id, list);
    }

    const stale: string[] = [];
    const outcomes = await Promise.allSettled(jobs.flatMap((j) =>
      (byUser.get(j.recipientId) ?? []).map(async (t) => {
        const outcome = await sendPush({
          token: t.token,
          title: j.title,
          body: j.body,
          data: { entityType: j.entityType, entityId: j.entityId, trigger: j.trigger },
          highPriority: j.priority === 'high' || j.priority === 'critical',
        });
        if (outcome === 'stale') stale.push(t.id);
        return outcome;
      })));
    pushed = outcomes.filter((o) => o.status === 'fulfilled' && o.value === 'sent').length;

    if (stale.length > 0) {
      await admin.from('device_tokens').update({ is_active: false }).in('id', stale);
    }
  }

  return json({ ok: true, delivered: jobs.length, pushed });
});
