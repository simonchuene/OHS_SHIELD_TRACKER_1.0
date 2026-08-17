// path: supabase/functions/user-admin/index.ts
// Prompt 5A — privileged User & Access Administration.
// ALL user-lifecycle mutations run here under the SERVICE ROLE, never from the
// Flutter client. Enforces: caller is an Administrator, same-company-only scope,
// lifecycle transition guards, and writes an audit_logs row (before/after) for
// every change. Deploy: `supabase functions deploy user-admin`.

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
// Where the invite email sends the user. Without it Supabase falls back to the
// project's Site URL, which defaulted to http://localhost:3000 — the invite
// sent successfully and its link went nowhere, so no invitee could ever set a
// password. Must also be listed under Authentication → URL Configuration →
// Redirect URLs, and match the app's deep-link intent-filter.
const AUTH_REDIRECT_URL = Deno.env.get('AUTH_REDIRECT_URL') ?? 'ohsshield://auth-callback';

// Allowed lifecycle transitions (mirrors domain UserLifecycle in Flutter).
const ALLOWED: Record<string, string[]> = {
  invited: ['active', 'deactivated'],
  active: ['suspended', 'deactivated'],
  suspended: ['active', 'deactivated'],
  deactivated: ['active'],
};
const BAN_FOREVER = '876000h'; // ~100 years
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing authorization' }, 401);

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  const asCaller = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } });

  // 1) Identify caller.
  const { data: userData, error: userErr } = await asCaller.auth.getUser();
  if (userErr || !userData.user) return json({ error: 'Invalid session' }, 401);
  const callerId = userData.user.id;

  // 2) Resolve caller company + verify Administrator (rank 5). Service role bypasses RLS.
  const { data: callerProfile } = await admin
    .from('user_profiles').select('company_id').eq('user_id', callerId).single();
  if (!callerProfile) return json({ error: 'No profile' }, 403);
  const companyId = callerProfile.company_id as string;

  const { data: callerRoles } = await admin
    .from('user_roles').select('roles(code)').eq('user_id', callerId).eq('company_id', companyId);
  const isAdmin = (callerRoles ?? []).some((r: any) => r.roles?.code === 'administrator');
  if (!isAdmin) return json({ error: 'Administrator role required' }, 403);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }
  const { action } = body ?? {};

  const audit = async (act: string, entityId: string | null, before: unknown, after: unknown) => {
    await admin.from('audit_logs').insert({
      company_id: companyId, actor_id: callerId, action: act,
      entity_type: 'user', entity_id: entityId, before_state: before, after_state: after,
    });
  };

  // Ensures the target belongs to the caller's company (no cross-company admin).
  const loadTarget = async (userId: string) => {
    const { data } = await admin.from('user_profiles').select('*').eq('user_id', userId).single();
    if (!data || data.company_id !== companyId) return null;
    return data;
  };

  const setStatus = async (userId: string, from: string, to: string, ban: boolean) => {
    if (!ALLOWED[from]?.includes(to)) {
      return json({ error: `Illegal transition ${from} -> ${to}` }, 409);
    }
    const patch: Record<string, unknown> = { status: to };
    if (to === 'active') patch.activated_at = new Date().toISOString();
    if (to === 'deactivated') patch.deactivated_at = new Date().toISOString();
    const before = await loadTarget(userId);
    const { data: after } = await admin.from('user_profiles').update(patch).eq('user_id', userId).select().single();
    await admin.auth.admin.updateUserById(userId, { ban_duration: ban ? BAN_FOREVER : 'none' });
    await audit(`user.${to}`, userId, before, after);
    return json({ ok: true, user: after });
  };

  try {
    switch (action) {
      case 'invite': {
        const { email, firstName, lastName, jobTitle, phone, siteId, departmentId,
          role, roleSiteId, roleDepartmentId } = body;
        if (!email || !firstName || !lastName || !role) return json({ error: 'Missing required fields' }, 400);

        const { data: invited, error: invErr } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo: AUTH_REDIRECT_URL });
        if (invErr || !invited.user) return json({ error: invErr?.message ?? 'Invite failed' }, 400);
        const newId = invited.user.id;

        const { data: roleRow } = await admin.from('roles').select('id').eq('code', role).single();
        if (!roleRow) return json({ error: 'Unknown role' }, 400);

        const { data: profile, error: pErr } = await admin.from('user_profiles').insert({
          user_id: newId, company_id: companyId, site_id: siteId ?? null,
          department_id: departmentId ?? null, first_name: firstName, last_name: lastName,
          job_title: jobTitle ?? null, phone: phone ?? null, status: 'invited',
          invited_at: new Date().toISOString(),
        }).select().single();
        if (pErr) return json({ error: pErr.message }, 400);

        await admin.from('user_roles').insert({
          user_id: newId, role_id: roleRow.id, company_id: companyId,
          site_id: roleSiteId ?? null, department_id: roleDepartmentId ?? null,
        });
        await audit('user.invited', newId, null, profile);
        return json({ ok: true, user: profile });
      }

      case 'resendInvite': {
        const target = await loadTarget(body.userId);
        if (!target) return json({ error: 'User not in your company' }, 403);
        const { data: u } = await admin.from('users').select('email').eq('id', body.userId).single();
        if (!u?.email) return json({ error: 'No email on file' }, 400);
        const { error } = await admin.auth.admin.inviteUserByEmail(u.email, { redirectTo: AUTH_REDIRECT_URL });
        if (error) return json({ error: error.message }, 400);
        await audit('user.invite_resent', body.userId, null, { email: u.email });
        return json({ ok: true });
      }

      case 'assignRoles': {
        // Replace the user's role assignments with the provided scope-aware set.
        const target = await loadTarget(body.userId);
        if (!target) return json({ error: 'User not in your company' }, 403);
        const desired: Array<{ role: string; siteId?: string; departmentId?: string }> = body.roles ?? [];
        const { data: before } = await admin.from('user_roles').select('*').eq('user_id', body.userId).eq('company_id', companyId);

        const { data: allRoles } = await admin.from('roles').select('id, code');
        const idByCode = new Map((allRoles ?? []).map((r: any) => [r.code, r.id]));

        await admin.from('user_roles').delete().eq('user_id', body.userId).eq('company_id', companyId);
        const rows = desired
          .filter((d) => idByCode.has(d.role))
          .map((d) => ({
            user_id: body.userId, role_id: idByCode.get(d.role), company_id: companyId,
            site_id: d.siteId ?? null, department_id: d.departmentId ?? null,
          }));
        if (rows.length > 0) await admin.from('user_roles').insert(rows);
        const { data: after } = await admin.from('user_roles').select('*').eq('user_id', body.userId).eq('company_id', companyId);
        await audit('user.roles_changed', body.userId, before, after);
        return json({ ok: true, roles: after });
      }

      case 'suspend': {
        const t = await loadTarget(body.userId);
        if (!t) return json({ error: 'User not in your company' }, 403);
        return await setStatus(body.userId, t.status, 'suspended', true);
      }
      case 'reactivate': {
        const t = await loadTarget(body.userId);
        if (!t) return json({ error: 'User not in your company' }, 403);
        return await setStatus(body.userId, t.status, 'active', false);
      }
      case 'deactivate': {
        const t = await loadTarget(body.userId);
        if (!t) return json({ error: 'User not in your company' }, 403);
        return await setStatus(body.userId, t.status, 'deactivated', true);
      }

      case 'resetPassword': {
        const t = await loadTarget(body.userId);
        if (!t) return json({ error: 'User not in your company' }, 403);
        const { data: u } = await admin.from('users').select('email').eq('id', body.userId).single();
        if (!u?.email) return json({ error: 'No email on file' }, 400);
        const { error } = await admin.auth.resetPasswordForEmail(u.email);
        if (error) return json({ error: error.message }, 400);
        await audit('user.password_reset_initiated', body.userId, null, { email: u.email });
        return json({ ok: true });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: `${e}` }, 500);
  }
});
