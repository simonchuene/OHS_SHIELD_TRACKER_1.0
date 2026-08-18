-- ===========================================================================
-- OHS Shield Tracker — realistic DEMO DATA for an existing company
-- ---------------------------------------------------------------------------
-- Populates hazards, risk assessments, incidents, investigations, corrective
-- actions and inspections (with items) so the dashboard, list screens, KPIs and
-- reports all have something credible to show.
--
-- Set v_company_code below. Defaults to 'MAMH'.
--
-- SAFE TO RE-RUN. Every row is tagged with a 'DEMO-' reference prefix and the
-- previous run's rows are deleted first, so you get one clean set rather than
-- duplicates. Nothing outside that prefix is touched.
--
-- WHO DOES WHAT
--   The script does not hardcode user IDs — it discovers the company's actual
--   users by role and assigns work the way the app expects: employees report,
--   safety officers assess and investigate, supervisors own corrective actions,
--   managers and administrators verify. Roles that the company does not have
--   fall back to the next-best available user, so this runs against a tenant
--   with five users or with one.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--   * No writes to auth.users — this only creates safety records.
--   * risk_level on hazards is left to the trg_risk_sync_hazard trigger (0014)
--     rather than being set by hand, so the demo exercises the real path.
--   * No notifications are generated: those come from the app and the edge
--     functions, so seeding cannot spam anyone's device.
--
-- Audit rows (0012/0013/0015) are written with a NULL actor_id, because the SQL
-- editor has no auth.uid(). That is expected for seeded data.
-- ===========================================================================

do $$
declare
  -- --- CONFIGURE --------------------------------------------------------
  v_company_code text := 'MAMH';
  -- ----------------------------------------------------------------------

  v_company uuid;
  v_site    uuid;
  v_site2   uuid;
  v_dept    uuid;

  -- Cast of characters, resolved by role below.
  v_admin      uuid;
  v_manager    uuid;
  v_officer    uuid;
  v_supervisor uuid;
  v_emp1       uuid;
  v_emp2       uuid;
  v_anyone     uuid;

  -- Record ids we need to wire together.
  v_hz1 uuid; v_hz2 uuid; v_hz3 uuid; v_hz4 uuid;
  v_hz5 uuid; v_hz6 uuid; v_hz7 uuid; v_hz8 uuid;
  v_in1 uuid; v_in2 uuid; v_in3 uuid; v_in4 uuid; v_in5 uuid;
  v_iv1 uuid; v_iv2 uuid; v_iv3 uuid;
  v_ins1 uuid; v_ins2 uuid; v_ins3 uuid; v_ins4 uuid;
  v_item_fail1 uuid; v_item_fail2 uuid;
begin
  -- --- resolve the tenant -------------------------------------------------
  select id into v_company from public.companies where code = v_company_code;
  if v_company is null then
    raise exception 'Company % does not exist. Check the code, or create the tenant first.',
      v_company_code;
  end if;

  select id into v_site  from public.sites where company_id = v_company
    order by created_at limit 1;
  select id into v_site2 from public.sites where company_id = v_company
    order by created_at offset 1 limit 1;
  v_site2 := coalesce(v_site2, v_site);   -- single-site tenants use the one site
  select id into v_dept from public.departments where company_id = v_company
    order by created_at limit 1;

  -- --- resolve the cast ---------------------------------------------------
  -- One user per role; the company's own people, not invented ones.
  select ur.user_id into v_admin from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'administrator' limit 1;
  select ur.user_id into v_manager from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'manager' limit 1;
  select ur.user_id into v_officer from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'safety_officer' limit 1;
  select ur.user_id into v_supervisor from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'supervisor' limit 1;
  select ur.user_id into v_emp1 from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'employee' limit 1;
  select ur.user_id into v_emp2 from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'employee'
     and ur.user_id <> coalesce(v_emp1, '00000000-0000-0000-0000-000000000000'::uuid)
   limit 1;

  -- Last resort: anyone at all in this company. reporter_id, assessor_id,
  -- investigator_id and inspector_id are all NOT NULL, so we need one real user.
  select user_id into v_anyone from public.user_profiles
   where company_id = v_company order by created_at limit 1;
  if v_anyone is null then
    raise exception 'Company % has no users. Seed at least one user before demo data.',
      v_company_code;
  end if;

  -- Collapse the gaps. A tenant missing a safety officer still gets coherent
  -- data — the nearest senior person stands in, exactly as would happen in real
  -- life on a small site.
  v_admin      := coalesce(v_admin, v_manager, v_officer, v_anyone);
  v_manager    := coalesce(v_manager, v_admin);
  v_officer    := coalesce(v_officer, v_manager, v_admin);
  v_supervisor := coalesce(v_supervisor, v_officer);
  v_emp1       := coalesce(v_emp1, v_supervisor, v_anyone);
  v_emp2       := coalesce(v_emp2, v_emp1);

  -- --- clear the previous demo run ---------------------------------------
  -- Deleting the demo hazards, incidents and inspections cascades to their risk
  -- assessments, investigations, inspection items and corrective actions, so
  -- these three statements remove the whole graph.
  delete from public.inspections
   where company_id = v_company and reference like 'DEMO-%';
  delete from public.incidents
   where company_id = v_company and reference like 'DEMO-%';
  delete from public.hazards
   where company_id = v_company and reference like 'DEMO-%';
  -- Any CAPA whose source row was already gone (defensive: orphans cannot exist
  -- under the ck_capa_one_source constraint, but a partial earlier run might).
  delete from public.corrective_actions
   where company_id = v_company and action_code like 'DEMO-%';

  -- =======================================================================
  -- HAZARDS  — a spread of categories, statuses and ages
  -- =======================================================================
  v_hz1 := gen_random_uuid(); v_hz2 := gen_random_uuid();
  v_hz3 := gen_random_uuid(); v_hz4 := gen_random_uuid();
  v_hz5 := gen_random_uuid(); v_hz6 := gen_random_uuid();
  v_hz7 := gen_random_uuid(); v_hz8 := gen_random_uuid();

  insert into public.hazards
    (id, company_id, site_id, department_id, reference, title, description,
     category, status, reporter_id, location_text, reported_at)
  values
    (v_hz1, v_company, v_site, v_dept, 'DEMO-HZ-001',
     'Hydraulic oil leak at press station 3',
     'Steady drip from the hydraulic hose union onto the walkway beside press 3. '
     'Floor is slippery within about a metre and absorbent granules are being '
     'reapplied every shift. Hose lagging is perished at the crimp.',
     'physical', 'capa', v_emp1, 'Press shop — station 3', now() - interval '19 days'),

    (v_hz2, v_company, v_site, v_dept, 'DEMO-HZ-002',
     'Drive chain guard removed on packing conveyor',
     'The mesh guard over the head-drive sprocket has been left off since the '
     'last jam clearance. Nip point is exposed at operator shoulder height and '
     'the line runs unattended between pack cycles.',
     'physical', 'investigation', v_emp2, 'Packing line 2 — head drive',
     now() - interval '12 days'),

    (v_hz3, v_company, v_site2, v_dept, 'DEMO-HZ-003',
     'Solvent decanting without local exhaust ventilation',
     'Thinners are decanted from 200L drums into 5L containers at an open bench. '
     'The extraction arm at that bench has no suction and vapour is noticeable '
     'across the store. No respiratory protection in use.',
     'chemical', 'assessment', v_emp1, 'Paint store — decanting bench',
     now() - interval '8 days'),

    (v_hz4, v_company, v_site, v_dept, 'DEMO-HZ-004',
     'Noise levels near compressor room door',
     'Conversation is not possible at the compressor room doorway with the door '
     'propped open for cooling. Staff pass through this route to the tool crib '
     'several times a shift without hearing protection.',
     'noise', 'capa', v_supervisor, 'Plant room corridor', now() - interval '15 days'),

    (v_hz5, v_company, v_site, v_dept, 'DEMO-HZ-005',
     'Repetitive lifting at the palletising station',
     'Cartons averaging 18 kg are lifted from floor level to shoulder height '
     'roughly 40 times an hour. Two operators have reported lower back '
     'discomfort at the end of shift.',
     'ergonomic', 'submitted', v_emp2, 'Dispatch — palletising', now() - interval '5 days'),

    (v_hz6, v_company, v_site, v_dept, 'DEMO-HZ-006',
     'Fire exit in dispatch bay blocked by stock',
     'Shrink-wrapped pallets stacked two deep against the emergency exit door, '
     'blocking the escape route entirely. Route cleared on the day and stock '
     'relocated behind the marked line.',
     'physical', 'closed', v_supervisor, 'Dispatch bay — south exit',
     now() - interval '34 days'),

    (v_hz7, v_company, v_site2, v_dept, 'DEMO-HZ-007',
     'Damaged extension leads in the maintenance workshop',
     'Three extension leads with cracked plug tops and taped outer sheathing '
     'still in service on the workshop benches. None carry a current inspection '
     'tag.',
     'physical', 'capa', v_emp1, 'Maintenance workshop', now() - interval '10 days'),

    (v_hz8, v_company, v_site, v_dept, 'DEMO-HZ-008',
     'Aggressive conduct from a contractor crew',
     'Repeated shouting and intimidating behaviour towards two general workers '
     'by a visiting installation crew. Raised with the contractor supervisor; '
     'staff have asked not to work alone in that area.',
     'psychosocial', 'submitted', v_emp2, 'Roof plant — chiller replacement',
     now() - interval '3 days');

  -- Close-out timestamp for the one resolved hazard.
  update public.hazards set closed_at = now() - interval '30 days' where id = v_hz6;

  -- =======================================================================
  -- RISK ASSESSMENTS — the trigger writes hazards.risk_level from these
  -- =======================================================================
  insert into public.risk_assessments
    (company_id, hazard_id, likelihood, severity, current_controls,
     required_controls, residual_likelihood, residual_severity,
     assessor_id, review_date, assessed_at)
  values
    (v_company, v_hz1, 4, 4,
     'Absorbent granules and a warning cone at the drip point.',
     'Replace the hose assembly, degrease the floor, and add the union to the '
     'weekly planned maintenance check.',
     2, 3, v_officer, (now() + interval '60 days')::date, now() - interval '18 days'),

    (v_company, v_hz2, 4, 5,
     'Verbal instruction not to reach into the drive while running.',
     'Refit the mesh guard, fit an interlock switch to the access panel, and '
     'brief the line on lockout before jam clearance.',
     1, 5, v_officer, (now() + interval '30 days')::date, now() - interval '11 days'),

    (v_company, v_hz3, 3, 5,
     'Doors propped open for cross-ventilation.',
     'Repair the extraction arm, provide a decanting pump with a closed '
     'coupling, and issue appropriate respiratory protection.',
     2, 4, v_officer, (now() + interval '45 days')::date, now() - interval '7 days'),

    (v_company, v_hz4, 4, 3,
     'Hearing protection available at the tool crib.',
     'Fit a self-closing door with an acoustic seal and signpost the corridor '
     'as a hearing protection zone.',
     2, 3, v_officer, (now() + interval '90 days')::date, now() - interval '14 days'),

    (v_company, v_hz5, 3, 3,
     'Team lifting encouraged for the heavier cartons.',
     'Introduce a scissor lift table at the palletising station and rotate '
     'operators through the role every two hours.',
     2, 2, v_officer, (now() + interval '75 days')::date, now() - interval '4 days'),

    (v_company, v_hz6, 3, 5,
     'Route inspected on the daily walk-around.',
     'Floor-mark a no-stacking zone at the exit and add it to the housekeeping '
     'inspection sheet.',
     1, 5, v_officer, (now() + interval '120 days')::date, now() - interval '33 days'),

    (v_company, v_hz7, 3, 4,
     'Visibly damaged leads withdrawn when noticed.',
     'Withdraw and replace all three leads, and put the workshop on a quarterly '
     'portable appliance inspection schedule.',
     1, 4, v_officer, (now() + interval '90 days')::date, now() - interval '9 days');

  -- =======================================================================
  -- INCIDENTS — some traceable back to a hazard that was already open
  -- =======================================================================
  v_in1 := gen_random_uuid(); v_in2 := gen_random_uuid(); v_in3 := gen_random_uuid();
  v_in4 := gen_random_uuid(); v_in5 := gen_random_uuid();

  insert into public.incidents
    (id, company_id, site_id, department_id, reference, incident_type, severity,
     status, occurred_at, location_text, description, witnesses, injured_party,
     source_hazard_id, reporter_id)
  values
    (v_in1, v_company, v_site, v_dept, 'DEMO-INC-001', 'near_miss', 'moderate',
     'investigated', now() - interval '9 days', 'Dispatch crossing',
     'A forklift travelling with a raised load braked hard to avoid a pedestrian '
     'stepping out from between racking. No contact. The pedestrian walkway '
     'marking has worn away at the crossing point.',
     '[{"name":"T. Nkosi","statement":"Heard the horn and saw the load shift forward."}]'::jsonb,
     null, null, v_emp1),

    (v_in2, v_company, v_site, v_dept, 'DEMO-INC-002', 'lost_time_injury', 'serious',
     'capa', now() - interval '11 days', 'Packing line 2 — head drive',
     'An operator clearing a carton jam contacted the moving drive chain and '
     'sustained a laceration to the left hand requiring sutures. The sprocket '
     'guard was not fitted at the time and the line had not been isolated.',
     '[{"name":"S. Adams","statement":"The line was still running when he reached in."}]'::jsonb,
     '{"role":"operator","injury":"laceration to left hand","treatment":"sutures, referred to clinic","days_lost":4}'::jsonb,
     v_hz2, v_supervisor),

    (v_in3, v_company, v_site2, v_dept, 'DEMO-INC-003', 'first_aid', 'minor',
     'closed', now() - interval '6 days', 'Paint store — decanting bench',
     'Thinners splashed onto an employee''s forearm while decanting from a drum '
     'without a pouring spout. Rinsed at the eyewash station for 15 minutes; no '
     'blistering and no time lost.',
     '[]'::jsonb,
     '{"role":"store assistant","injury":"chemical splash to right forearm","treatment":"irrigation, first aid only","days_lost":0}'::jsonb,
     v_hz3, v_emp1),

    (v_in4, v_company, v_site, v_dept, 'DEMO-INC-004', 'property_damage', 'moderate',
     'reported', now() - interval '2 days', 'Warehouse aisle C',
     'A reach truck struck the upright of pallet racking bay C14 while '
     'reversing. The upright is deformed at about 400 mm and the bay has been '
     'cordoned off and off-loaded pending inspection.',
     '[{"name":"J. Petersen"}]'::jsonb, null, null, v_emp2),

    (v_in5, v_company, v_site, v_dept, 'DEMO-INC-005', 'environmental_incident', 'moderate',
     'capa', now() - interval '16 days', 'Press shop — external drain',
     'Hydraulic oil tracked out of the press shop on foot traffic and entered '
     'the stormwater drain at the roller door. Approximately 5 litres. Drain '
     'isolated with a spill sock and the contractor recovered the residue.',
     '[]'::jsonb, null, v_hz1, v_supervisor);

  update public.incidents
     set verified_by = v_manager, verified_at = now() - interval '5 days',
         closed_at   = now() - interval '5 days'
   where id = v_in3;

  -- =======================================================================
  -- INVESTIGATIONS — exactly one source each (ck_investigations_one_source)
  -- =======================================================================
  v_iv1 := gen_random_uuid(); v_iv2 := gen_random_uuid(); v_iv3 := gen_random_uuid();

  insert into public.investigations
    (id, company_id, site_id, incident_id, hazard_id, method, immediate_cause,
     contributing_factors, root_cause, recommendations, analysis,
     investigator_id, status, opened_at, completed_at)
  values
    (v_iv1, v_company, v_site, v_in2, null, 'five_whys',
     'The operator reached into an unguarded, energised drive to clear a jam.',
     'The guard had been left off after a previous jam; jams occur several times '
     'a shift; stopping the line is seen as costing throughput; no lockout point '
     'is fitted at the head drive; the task is not covered by a safe work '
     'procedure.',
     'Jam clearance was never designed as a task. With no quick isolation and '
     'production pressure against stopping the line, removing the guard became '
     'the accepted method and supervision treated it as normal.',
     'Fit an interlocked guard so the line cannot run with the panel open; '
     'install a local isolator at the head drive; write and train a jam-clearance '
     'procedure; investigate the carton feed causing the jams.',
     '{"why":['
       '{"q":"Why was the hand injured?","a":"It contacted a moving drive chain."},'
       '{"q":"Why was the chain accessible?","a":"The guard was not fitted."},'
       '{"q":"Why was the guard not fitted?","a":"It was removed to clear a jam and left off."},'
       '{"q":"Why was it left off?","a":"Jams recur constantly and refitting it each time slows the line."},'
       '{"q":"Why is that acceptable?","a":"No isolation point or approved jam-clearance method exists."}'
     ']}'::jsonb,
     v_officer, 'completed', now() - interval '11 days', now() - interval '4 days'),

    (v_iv2, v_company, v_site, v_in1, null, 'five_whys',
     'A pedestrian entered the forklift travel route at an unmarked crossing.',
     'Walkway paint worn away; racking obscures the sight line; no mirror at the '
     'corner; pedestrians take this route to reach the dispatch office.',
     null,
     null,
     '{"why":['
       '{"q":"Why the near-miss?","a":"A pedestrian stepped into the travel route."},'
       '{"q":"Why there?","a":"It is the shortest route to the dispatch office."},'
       '{"q":"Why was it unsafe?","a":"The crossing markings have worn away and the sight line is blocked."}'
     ']}'::jsonb,
     v_officer, 'in_progress', now() - interval '8 days', null),

    (v_iv3, v_company, v_site, null, v_hz2, 'fishbone',
     'Guarding on the packing line is removed routinely rather than exceptionally.',
     'Method: no approved jam-clearance procedure. Machine: no interlock, no '
     'local isolator. People: crews rotate and are trained on the job. '
     'Management: line stoppages are reported as downtime against the shift.',
     'Guard removal is a symptom of an unreliable carton feed combined with a '
     'measurement system that penalises stopping the line.',
     'Treat the feed reliability as the primary fix; interlock the guard so the '
     'unsafe option is removed; stop counting safety stops as shift downtime.',
     '{"categories":{'
       '"method":["no jam-clearance procedure","clearing on the run is custom"],'
       '"machine":["no interlock","no local isolator","carton feed misaligns"],'
       '"people":["rotating crews","on-the-job training only"],'
       '"management":["downtime counted against the shift"]}}'::jsonb,
     v_officer, 'pending_review', now() - interval '6 days', null);

  -- =======================================================================
  -- INSPECTIONS + ITEMS
  -- =======================================================================
  v_ins1 := gen_random_uuid(); v_ins2 := gen_random_uuid();
  v_ins3 := gen_random_uuid(); v_ins4 := gen_random_uuid();
  v_item_fail1 := gen_random_uuid(); v_item_fail2 := gen_random_uuid();

  insert into public.inspections
    (id, company_id, site_id, department_id, reference, inspection_type,
     inspector_id, status, scheduled_date, conducted_at, score)
  values
    (v_ins1, v_company, v_site, v_dept, 'DEMO-INS-001', 'housekeeping', v_officer,
     'submitted', (now() - interval '7 days')::date, now() - interval '7 days', 78.00),
    (v_ins2, v_company, v_site, v_dept, 'DEMO-INS-002', 'fire_safety', v_officer,
     'closed', (now() - interval '21 days')::date, now() - interval '21 days', 92.00),
    (v_ins3, v_company, v_site2, v_dept, 'DEMO-INS-003', 'ppe', v_supervisor,
     'in_progress', (now() - interval '1 day')::date, null, null),
    -- Scheduled and still in draft: this is what the inspection.due sweep looks for.
    (v_ins4, v_company, v_site, v_dept, 'DEMO-INS-004', 'vehicle', v_supervisor,
     'draft', (now() + interval '4 days')::date, null, null);

  insert into public.inspection_items
    (id, company_id, inspection_id, position, prompt, result, notes)
  values
    (gen_random_uuid(), v_company, v_ins1, 1,
     'Walkways and aisles clear of obstruction', 'pass', null),
    (gen_random_uuid(), v_company, v_ins1, 2,
     'Waste and offcuts in designated bins', 'pass', null),
    (v_item_fail1, v_company, v_ins1, 3,
     'Floors free of spills and slip hazards', 'fail',
     'Oil film on the walkway beside press 3; granules down but not cleaned up.'),
    (gen_random_uuid(), v_company, v_ins1, 4,
     'Storage racking loaded within marked limits', 'pass', null),
    (v_item_fail2, v_company, v_ins1, 5,
     'Emergency exits and routes unobstructed', 'fail',
     'Dispatch south exit partially blocked by shrink-wrapped pallets.'),
    (gen_random_uuid(), v_company, v_ins1, 6,
     'Lighting adequate in work areas', 'pass', null),

    (gen_random_uuid(), v_company, v_ins2, 1,
     'Extinguishers in place, sealed and in date', 'pass', null),
    (gen_random_uuid(), v_company, v_ins2, 2,
     'Hose reels accessible and serviceable', 'pass', null),
    (gen_random_uuid(), v_company, v_ins2, 3,
     'Detection panel showing no faults', 'pass', null),
    (gen_random_uuid(), v_company, v_ins2, 4,
     'Assembly point signage legible', 'na',
     'Signage replacement scheduled with the landlord.'),
    (gen_random_uuid(), v_company, v_ins2, 5,
     'Evacuation drill within the last six months', 'pass', null),

    (gen_random_uuid(), v_company, v_ins3, 1,
     'Eye protection worn in designated areas', 'pass', null),
    (gen_random_uuid(), v_company, v_ins3, 2,
     'Hearing protection available at point of use', null, null),
    (gen_random_uuid(), v_company, v_ins3, 3,
     'Safety footwear in serviceable condition', null, null);

  -- Link the failed housekeeping items to the hazards they correspond to,
  -- mirroring what the app does when an inspector fails an item.
  update public.inspection_items set generated_hazard_id = v_hz1 where id = v_item_fail1;
  update public.inspection_items set generated_hazard_id = v_hz6 where id = v_item_fail2;

  -- =======================================================================
  -- CORRECTIVE ACTIONS — all four origins, statuses across the lifecycle,
  -- and a deliberate mix of overdue / due soon / closed so the KPIs move.
  -- =======================================================================
  insert into public.corrective_actions
    (company_id, site_id, action_code, description, priority, owner_id, due_date,
     status, hazard_id, incident_id, investigation_id, inspection_item_id,
     verified_by, verified_at, verification_notes, completion_notes, closed_at,
     created_at)
  values
    -- From hazards
    (v_company, v_site, 'DEMO-CA-001',
     'Replace the perished hydraulic hose assembly on press 3 and degrease the '
     'walkway. Add the union to the weekly planned maintenance check.',
     'high', v_supervisor, (now() - interval '3 days')::date, 'in_progress',
     v_hz1, null, null, null, null, null, null, null, null, now() - interval '18 days'),

    (v_company, v_site, 'DEMO-CA-002',
     'Signpost the plant room corridor as a hearing protection zone and fit a '
     'self-closing acoustic door to the compressor room.',
     'medium', v_supervisor, (now() + interval '12 days')::date, 'assigned',
     v_hz4, null, null, null, null, null, null, null, null, now() - interval '14 days'),

    (v_company, v_site2, 'DEMO-CA-003',
     'Withdraw the three damaged extension leads from service, replace them, and '
     'place the workshop on a quarterly portable appliance inspection schedule.',
     'medium', v_emp1, (now() - interval '1 day')::date, 'verification',
     v_hz7, null, null, null, null, null, null,
     'All three leads replaced with moulded-plug assemblies and tagged. '
     'Quarterly inspection added to the maintenance planner — first round due '
     'next quarter.', null, now() - interval '9 days'),

    (v_company, v_site2, 'DEMO-CA-004',
     'Repair the local exhaust ventilation arm at the decanting bench and '
     'provide a drum pump with a closed coupling.',
     'critical', v_supervisor, (now() + interval '5 days')::date, 'in_progress',
     v_hz3, null, null, null, null, null, null, null, null, now() - interval '7 days'),

    -- From incidents
    (v_company, v_site, 'DEMO-CA-005',
     'Repaint the pedestrian crossing at the dispatch aisle and fit a convex '
     'mirror at the racking corner.',
     'high', v_supervisor, (now() + interval '2 days')::date, 'assigned',
     null, v_in1, null, null, null, null, null, null, null, now() - interval '8 days'),

    (v_company, v_site, 'DEMO-CA-006',
     'Contain and recover the hydraulic oil at the stormwater drain, and fit a '
     'kerb spill kit at the roller door.',
     'high', v_emp1, (now() - interval '6 days')::date, 'closed',
     null, v_in5, null, null, v_manager, now() - interval '5 days',
     'Drain cleared and spill kit in place. Verified on site.',
     'Spill sock deployed on the day and residue recovered by the contractor. '
     'Kerb spill kit mounted beside the roller door and the dispatch team briefed '
     'on where it is.', now() - interval '5 days', now() - interval '15 days'),

    -- From an investigation
    (v_company, v_site, 'DEMO-CA-007',
     'Fit an interlocked guard to the packing line head drive so the line cannot '
     'run with the access panel open, and install a local isolator.',
     'critical', v_supervisor, (now() + interval '7 days')::date, 'in_progress',
     null, null, v_iv1, null, null, null, null, null, null, now() - interval '4 days'),

    (v_company, v_site, 'DEMO-CA-008',
     'Write a jam-clearance safe work procedure for the packing lines and train '
     'all shift crews against it.',
     'high', v_officer, (now() + interval '18 days')::date, 'created',
     null, null, v_iv1, null, null, null, null, null, null, now() - interval '4 days'),

    -- From inspection items
    (v_company, v_site, 'DEMO-CA-009',
     'Deep-clean the press shop walkway and re-treat the surface with '
     'anti-slip coating.',
     'medium', v_emp2, (now() - interval '2 days')::date, 'verification',
     null, null, null, v_item_fail1, null, null, null,
     'Walkway degreased and anti-slip coating applied over the weekend '
     'shutdown. Left to cure for 24 hours before the area was reopened.',
     null, now() - interval '7 days'),

    (v_company, v_site, 'DEMO-CA-010',
     'Floor-mark a no-stacking zone at the dispatch south exit and add the '
     'route to the daily housekeeping check.',
     'high', v_supervisor, (now() - interval '20 days')::date, 'closed',
     null, null, null, v_item_fail2, v_manager, now() - interval '19 days',
     'Zone marked and check sheet updated. Confirmed clear on two follow-up '
     'walk-arounds.',
     'Hatched no-stacking zone painted at the exit and the route added to the '
     'daily housekeeping sheet.', now() - interval '19 days', now() - interval '30 days');

  raise notice 'Demo data seeded for company % (site %, department %)',
    v_company_code, coalesce(v_site::text, 'none'), coalesce(v_dept::text, 'none');
end $$;

-- --- verify -----------------------------------------------------------------
-- Counts per entity, restricted to the demo set where it is identifiable.
select 'hazards'            as entity, count(*) from public.hazards
  where reference like 'DEMO-%'
union all
select 'risk_assessments',  count(*) from public.risk_assessments ra
  join public.hazards h on h.id = ra.hazard_id where h.reference like 'DEMO-%'
union all
select 'incidents',         count(*) from public.incidents where reference like 'DEMO-%'
union all
select 'investigations',    count(*) from public.investigations iv
  left join public.hazards   h on h.id = iv.hazard_id
  left join public.incidents i on i.id = iv.incident_id
  where h.reference like 'DEMO-%' or i.reference like 'DEMO-%'
union all
select 'inspections',       count(*) from public.inspections where reference like 'DEMO-%'
union all
select 'inspection_items',  count(*) from public.inspection_items ii
  join public.inspections ins on ins.id = ii.inspection_id
  where ins.reference like 'DEMO-%'
union all
select 'corrective_actions', count(*) from public.corrective_actions
  where action_code like 'DEMO-%';

-- Hazards with the risk band the trigger derived from their assessment.
select h.reference, h.title, h.category, h.status, h.risk_level
  from public.hazards h
 where h.reference like 'DEMO-%'
 order by h.reference;

-- CAPA workload by owner, so you can confirm the assignments landed on real users.
select ca.action_code, ca.status, ca.priority, ca.due_date,
       coalesce(p.first_name || ' ' || p.last_name, '(unassigned)') as owner
  from public.corrective_actions ca
  left join public.user_profiles p on p.user_id = ca.owner_id
 where ca.action_code like 'DEMO-%'
 order by ca.action_code;
