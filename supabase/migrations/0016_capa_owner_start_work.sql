-- ===========================================================================
-- 0016  CAPA owner may start work
-- ---------------------------------------------------------------------------
-- Let a CAPA's assigned owner update their own action (notably Assigned ->
-- In Progress, "Start work") without needing Supervisor rank. Moving a CAPA to
-- Verification or Closed still requires Safety Officer+ (rank >= 3) via the
-- WITH CHECK, so an owner cannot self-verify or self-close.
-- ===========================================================================
drop policy if exists capa_update on public.corrective_actions;
create policy capa_update on public.corrective_actions
  for update to authenticated
  using (
    company_id = app.current_company_id()
    and (app.has_min_rank(2) or owner_id = auth.uid())
  )
  with check (
    company_id = app.current_company_id()
    and (status not in ('verification','closed') or app.has_min_rank(3))  -- Verify & Close CAPA = SO+
  );
