-- ===========================================================================
-- 0018  CAPA completion notes + owner may submit their own work
-- ---------------------------------------------------------------------------
-- Two related changes so the person who does the work can record what they did
-- and hand it back.
--
-- 1. `completion_notes` — the OWNER's account of the work performed, written
--    when submitting for verification. Deliberately separate from
--    `verification_notes`, which is the VERIFIER's rationale for accepting it.
--    Collapsing the two would leave an audit record where it is impossible to
--    tell who wrote which, and a CAPA's evidence trail is exactly the thing a
--    regulator reads.
--
-- 2. RLS: an owner may move their own CAPA In Progress -> Verification.
--    Previously the WITH CHECK gated both 'verification' and 'closed' at
--    Safety Officer+, so an Employee owner could Start work (0016) but could
--    not hand it back — someone senior had to submit on their behalf, and there
--    was no transition of theirs to attach completion notes to.
--
--    Closing still requires Safety Officer+, so an owner can neither verify nor
--    close their own action. The separation of duties that matters is intact.
-- ===========================================================================

alter table public.corrective_actions
  add column if not exists completion_notes text;

comment on column public.corrective_actions.completion_notes is
  'Owner''s account of the work performed, captured when submitting for verification. Distinct from verification_notes (the verifier''s rationale).';

drop policy if exists capa_update on public.corrective_actions;
create policy capa_update on public.corrective_actions
  for update to authenticated
  using (
    company_id = app.current_company_id()
    and (app.has_min_rank(2) or owner_id = auth.uid())  -- owner may act on their own CAPA (0016)
  )
  with check (
    company_id = app.current_company_id()
    and (
      status not in ('verification', 'closed')
      or app.has_min_rank(3)                                  -- Verify & Close CAPA = SO+
      or (status = 'verification' and owner_id = auth.uid())  -- 0018: owner may submit their own work
    )
  );
