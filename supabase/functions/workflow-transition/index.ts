// path: supabase/functions/workflow-transition/index.ts
// Prompt 8 / 8A — authoritative workflow transitions for guarded status changes.
// Handles Hazard AND Incident → Closed, enforcing (server-side, non-bypassable):
//   • caller is Safety Officer+ (rank >= 3) in the record's company, and
//   • verification evidence exists (>= 1 active attachment), and
//   • every linked corrective action is closed.
// The audit_logs row is written by the table trigger (<entity>.status_changed).
// Deploy: `supabase functions deploy workflow-transition`.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const URL = Deno.env.get('SUPABASE_URL')!;
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const RANK: Record<string, number> = {
  employee: 1, supervisor: 2, safety_officer: 3, manager: 4, administrator: 5,
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing authorization' }, 401);

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  const asCaller = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } });

  const { data: u } = await asCaller.auth.getUser();
  if (!u.user) return json({ error: 'Invalid session' }, 401);
  const callerId = u.user.id;

  const { data: profile } = await admin.from('user_profiles').select('company_id').eq('user_id', callerId).single();
  if (!profile) return json({ error: 'No profile' }, 403);
  const companyId = profile.company_id as string;

  const { data: roles } = await admin.from('user_roles').select('roles(code)').eq('user_id', callerId).eq('company_id', companyId);
  const rank = Math.max(0, ...((roles ?? []).map((r: any) => RANK[r.roles?.code] ?? 0)));

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }
  const { entityType, id, to } = body ?? {};

  // Map entity → (table, capa FK column, owner_type for evidence).
  const cfg: Record<string, { table: string; capaFk: string }> = {
    hazard: { table: 'hazards', capaFk: 'hazard_id' },
    incident: { table: 'incidents', capaFk: 'incident_id' },
  };
  const conf = cfg[entityType];
  if (!conf || !id || !to) return json({ error: 'Unsupported request' }, 400);

  const { data: record } = await admin.from(conf.table).select('*').eq('id', id).single();
  if (!record || record.company_id !== companyId) return json({ error: 'Not in your company' }, 403);

  if (to === 'closed') {
    if (rank < 3) return json({ error: `Closing requires Safety Officer or above.` }, 403);

    // Guard 1: verification evidence present.
    const { count: evidence } = await admin
      .from('attachments').select('id', { count: 'exact', head: true })
      .eq('owner_type', entityType).eq('owner_id', id).eq('is_active', true);
    if (!evidence || evidence < 1) {
      return json({ error: 'Attach verification evidence before closing.' }, 409);
    }

    // Guard 2: all linked corrective actions closed.
    const { data: openCapas } = await admin
      .from('corrective_actions').select('id, status').eq(conf.capaFk, id).neq('status', 'closed');
    if ((openCapas ?? []).length > 0) {
      return json({ error: 'All linked corrective actions must be closed first.' }, 409);
    }

    const { data: updated } = await admin.from(conf.table)
      .update({ status: 'closed', closed_at: new Date().toISOString() })
      .eq('id', id).select().single();
    return json({ ok: true, record: updated });
  }

  // Non-close transitions: Supervisor+ (RLS also enforces). Advance status only.
  if (rank < 2) return json({ error: 'Insufficient permission.' }, 403);
  const { data: updated, error } = await admin.from(conf.table).update({ status: to }).eq('id', id).select().single();
  if (error) return json({ error: error.message }, 400);
  return json({ ok: true, record: updated });
});
