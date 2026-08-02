// path: supabase/functions/inspection-item-fail/index.ts
// Prompt 12 — when an inspection item is marked FAIL, atomically create a Hazard
// AND a CAPA linked to that item (Master Prompt INSPECTIONS). Idempotent: if the
// item already generated them, returns the existing ids. Service-role; caller
// must be Supervisor+ in the item's company. Audit rows are written by table
// triggers (hazard.created / corrective_action.created).
// Deploy: `supabase functions deploy inspection-item-fail`.

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
const RANK: Record<string, number> = { employee: 1, supervisor: 2, safety_officer: 3, manager: 4, administrator: 5 };
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
  if (rank < 2) return json({ error: 'Conducting inspections requires Supervisor or above.' }, 403);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }
  const itemId = body?.inspectionItemId;
  if (!itemId) return json({ error: 'inspectionItemId required' }, 400);

  const { data: item } = await admin.from('inspection_items').select('*').eq('id', itemId).single();
  if (!item || item.company_id !== companyId) return json({ error: 'Item not in your company' }, 403);
  if (item.result !== 'fail') return json({ error: 'Item is not a fail' }, 409);

  // Idempotent — already generated.
  if (item.generated_hazard_id && item.generated_capa_id) {
    return json({ ok: true, hazardId: item.generated_hazard_id, capaId: item.generated_capa_id, existed: true });
  }

  // Parent inspection provides site scope.
  const { data: inspection } = await admin.from('inspections').select('site_id, department_id').eq('id', item.inspection_id).single();
  const siteId = inspection?.site_id ?? null;

  const { data: hazard } = await admin.from('hazards').insert({
    company_id: companyId, site_id: siteId, department_id: inspection?.department_id ?? null,
    title: `Failed inspection: ${item.prompt}`.substring(0, 120),
    description: item.notes, category: 'physical', status: 'submitted', reporter_id: callerId,
  }).select('id').single();

  const { data: capa } = await admin.from('corrective_actions').insert({
    company_id: companyId, site_id: siteId, inspection_item_id: itemId,
    description: `Address failed inspection item: ${item.prompt}`, priority: 'medium', status: 'created',
  }).select('id').single();

  await admin.from('inspection_items').update({
    generated_hazard_id: hazard?.id, generated_capa_id: capa?.id,
  }).eq('id', itemId);

  return json({ ok: true, hazardId: hazard?.id, capaId: capa?.id });
});
