-- path: supabase/seed.sql
-- Reference data ONLY. Per the Master Prompt DATA QUALITY RULE, no sample
-- companies, users, hazards, incidents, or inspections are seeded.
-- Only the five locked RBAC roles are inserted (global reference data).

insert into public.roles (code, name, rank) values
  ('employee',       'Employee',       1),
  ('supervisor',     'Supervisor',     2),
  ('safety_officer', 'Safety Officer', 3),
  ('manager',        'Manager',        4),
  ('administrator',  'Administrator',  5)
on conflict (code) do nothing;
