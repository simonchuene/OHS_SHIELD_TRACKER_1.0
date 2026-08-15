// path: supabase/functions/notify-fanout/index.ts
// Prompt 15 — fan out a domain event into in-app notifications (+ FCM push).
// Called by the app's NotificationTriggers dispatcher. Service role inserts
// `notifications` rows (client INSERT is denied by RLS) for the resolved
// recipients, then best-effort pushes via FCM to their `device_tokens`.
// Deploy: `supabase functions deploy notify-fanout`.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { fcmConfigured, sendPush } from '../_shared/fcm.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const URL = Deno.env.get('SUPABASE_URL')!;
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

// Client fires dotted names (D7); the DB enum uses underscores.
const toEnum = (t: string) => t.replace('.', '_');

const defaults: Record<string, { title: string; body: string; priority: string }> = {
  hazard_created: { title: 'New hazard reported', body: 'A hazard needs attention.', priority: 'normal' },
  incident_created: { title: 'New incident reported', body: 'An incident was reported.', priority: 'high' },
  risk_assessed: { title: 'Risk assessment updated', body: 'A hazard was assessed.', priority: 'normal' },
  capa_assigned: { title: 'CAPA assigned to you', body: 'You have a new corrective action.', priority: 'normal' },
  capa_overdue: { title: 'CAPA overdue', body: 'A corrective action is overdue.', priority: 'high' },
  investigation_due: { title: 'Investigation due', body: 'An investigation needs progress.', priority: 'normal' },
  inspection_due: { title: 'Inspection due', body: 'An inspection is due.', priority: 'normal' },
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing authorization' }, 401);

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  const asCaller = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } });

  const { data: u } = await asCaller.auth.getUser();
  if (!u.user) return json({ error: 'Invalid session' }, 401);
  const callerId = u.user.id;
  const { data: profile } = await admin.from('user_profiles').select('company_id, site_id').eq('user_id', callerId).single();
  if (!profile) return json({ error: 'No profile' }, 403);
  const companyId = profile.company_id as string;

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }
  const { trigger, entityType, entityId } = body ?? {};
  if (!trigger || !entityType || !entityId) return json({ error: 'trigger, entityType, entityId required' }, 400);

  const triggerEnum = toEnum(trigger);
  const d = defaults[triggerEnum] ?? { title: trigger, body: '', priority: 'normal' };
  const title = body.title ?? d.title;
  const message = body.body ?? d.body;
  const priority = body.priority ?? d.priority;

  // Resolve recipients within the caller's company.
  let recipients: string[] = Array.isArray(body.recipientIds) ? body.recipientIds : [];
  if (recipients.length === 0) {
    if (triggerEnum === 'capa_assigned') {
      const { data: capa } = await admin.from('corrective_actions').select('owner_id').eq('id', entityId).single();
      if (capa?.owner_id) recipients = [capa.owner_id];
    }
    if (recipients.length === 0) {
      // Default audience: Safety Officer+ (rank >= 3) in the company.
      const { data: roleRows } = await admin
        .from('user_roles').select('user_id, roles(code)').eq('company_id', companyId);
      const rank: Record<string, number> = { safety_officer: 3, manager: 4, administrator: 5 };
      recipients = [...new Set((roleRows ?? []).filter((r: any) => (rank[r.roles?.code] ?? 0) >= 3).map((r: any) => r.user_id))];
    }
  }
  if (recipients.length === 0) return json({ ok: true, delivered: 0 });

  // In-app notifications.
  await admin.from('notifications').insert(recipients.map((rid) => ({
    company_id: companyId, recipient_id: rid, trigger_type: triggerEnum, priority,
    title, body: message, entity_type: entityType, entity_id: entityId,
  })));

  // Push (best-effort). Requires FIREBASE_SERVICE_ACCOUNT; skipped gracefully
  // otherwise — the in-app rows above are the guaranteed channel.
  let pushed = 0;
  if (fcmConfigured) {
    const { data: tokens } = await admin
      .from('device_tokens').select('id, token').in('user_id', recipients).eq('is_active', true);

    const stale: string[] = [];
    const outcomes = await Promise.allSettled((tokens ?? []).map(async (t: { id: string; token: string }) => {
      const outcome = await sendPush({
        token: t.token,
        title,
        body: message,
        data: { entityType: String(entityType), entityId: String(entityId), trigger: triggerEnum },
        highPriority: priority === 'high' || priority === 'critical',
      });
      if (outcome === 'stale') stale.push(t.id);
      return outcome;
    }));
    pushed = outcomes.filter((o) => o.status === 'fulfilled' && o.value === 'sent').length;

    // Retire tokens FCM rejected outright, so a dead device stops costing a
    // send on every future fan-out.
    if (stale.length > 0) {
      await admin.from('device_tokens').update({ is_active: false }).in('id', stale);
    }
  }

  return json({ ok: true, delivered: recipients.length, pushed });
});
