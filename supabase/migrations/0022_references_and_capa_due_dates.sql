-- path: supabase/migrations/0022_references_and_capa_due_dates.sql
-- Two gaps found when the inspection auto-generation ran against real data:
--
--   1. Nothing ever wrote `reference` / `action_code`. 0003 describes the
--      hazard one as "assigned on submit", but no code path in the client or
--      the edge functions assigned it, so every record was identifiable only
--      by its internal uuid. Four tables carry the column and a
--      unique (company_id, <col>) constraint that had never been exercised.
--
--   2. Auto-generated corrective actions had no due date, which means the
--      overdue sweep (0017) could never fire on them. An action nobody is
--      chased for is not a corrective action.
--
-- Both are fixed in the database rather than in the callers. Assignment has to
-- hold for the app, the inspection-item-fail function, the seed scripts and
-- whatever writes these tables next; a trigger is the only place that covers
-- the caller that has not been written yet.

-- ---------------------------------------------------------------------------
-- Counter store
-- ---------------------------------------------------------------------------
-- One counter per (company, prefix, year). A table rather than a sequence
-- because sequences cannot be created per tenant without DDL at runtime, and
-- because `on conflict do update ... returning` is atomic: two concurrent
-- inserts serialise on the row and cannot take the same number. The unique
-- constraints on the target tables are the backstop if that reasoning is wrong.
create table if not exists public.reference_counters (
  company_id uuid not null references public.companies(id) on delete cascade,
  prefix     text not null,
  year       int  not null,
  next_value int  not null default 0,
  primary key (company_id, prefix, year)
);

-- Internal bookkeeping: no client ever reads or writes this. RLS on with no
-- policies denies everything; the SECURITY DEFINER function below is the only
-- way in.
alter table public.reference_counters enable row level security;

create or replace function app.next_reference(p_company uuid, p_prefix text, p_year int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next int;
begin
  insert into public.reference_counters (company_id, prefix, year, next_value)
  values (p_company, p_prefix, p_year, 1)
  on conflict (company_id, prefix, year)
    do update set next_value = public.reference_counters.next_value + 1
  returning next_value into v_next;
  return v_next;
end;
$$;

-- ---------------------------------------------------------------------------
-- Assignment trigger
-- ---------------------------------------------------------------------------
-- Generic over the column name so one function serves `reference` on three
-- tables and `action_code` on a fourth. Fields are read and written through
-- jsonb rather than as column references, which is what lets the same function
-- attach to tables with different shapes — and avoids the plan-time failure
-- that broke 0012 (see 0021: a column named in PL/pgSQL must exist on every
-- table the function is attached to, whether or not the branch runs).
--
-- Two rules decide whether a number is owed:
--   * A value already present is never overwritten — explicit references from
--     the seed scripts survive, and re-assignment on later updates is skipped.
--   * Drafts do not consume numbers. Hazards and inspections both start as
--     drafts, and a discarded draft should not leave a gap in the register.
--     The number is assigned when the row first leaves draft, which is what
--     0003 meant by "assigned on submit". Incidents and corrective actions
--     have no draft state, so they are numbered at insert.
create or replace function app.assign_reference()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_col    text  := tg_argv[0];
  v_prefix text  := tg_argv[1];
  v_row    jsonb := to_jsonb(new);
  v_year   int   := extract(year from now())::int;
  v_seq    int;
begin
  if v_row ? v_col and v_row->>v_col is not null then
    return new;
  end if;
  if v_row->>'status' = 'draft' then
    return new;
  end if;

  v_seq := app.next_reference(new.company_id, v_prefix, v_year);

  return jsonb_populate_record(
    new,
    jsonb_build_object(v_col, v_prefix || '-' || v_year || '-' || lpad(v_seq::text, 4, '0'))
  );
end;
$$;

drop trigger if exists trg_hazards_reference on public.hazards;
create trigger trg_hazards_reference
  before insert or update on public.hazards
  for each row execute function app.assign_reference('reference', 'HZ');

drop trigger if exists trg_incidents_reference on public.incidents;
create trigger trg_incidents_reference
  before insert or update on public.incidents
  for each row execute function app.assign_reference('reference', 'INC');

drop trigger if exists trg_inspections_reference on public.inspections;
create trigger trg_inspections_reference
  before insert or update on public.inspections
  for each row execute function app.assign_reference('reference', 'INS');

drop trigger if exists trg_capa_action_code on public.corrective_actions;
create trigger trg_capa_action_code
  before insert or update on public.corrective_actions
  for each row execute function app.assign_reference('action_code', 'CA');

-- ---------------------------------------------------------------------------
-- Corrective action due dates
-- ---------------------------------------------------------------------------
-- Lead time by priority. These are the target dates the escalation rules
-- already assume exist: CapaEscalationRules treats critical as always
-- escalating and warns two days out, but with a null due_date it returns
-- `none` and the row is invisible to the sweep.
--
-- Applied only when no date was given, and only on insert — clearing a due
-- date on an existing action is a deliberate act and is left alone.
create or replace function app.default_capa_due_date()
returns trigger
language plpgsql
as $$
begin
  if new.due_date is null then
    new.due_date := current_date + case new.priority
                                     when 'critical' then 3
                                     when 'high'     then 7
                                     when 'medium'   then 14
                                     else 30
                                   end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_capa_due_date on public.corrective_actions;
create trigger trg_capa_due_date
  before insert on public.corrective_actions
  for each row execute function app.default_capa_due_date();

-- ---------------------------------------------------------------------------
-- Backfill
-- ---------------------------------------------------------------------------
-- Existing rows predate the trigger. Numbering them in creation order per
-- company and year keeps the register readable rather than leaving a block of
-- unnumbered records ahead of the numbered ones. Drafts are skipped for the
-- same reason as above; they pick up a number when they are submitted.
do $$
declare
  t record;
begin
  for t in
    select * from (values
      ('hazards',            'reference',   'HZ',  true),
      ('incidents',          'reference',   'INC', false),
      ('inspections',        'reference',   'INS', true),
      ('corrective_actions', 'action_code', 'CA',  false)
    ) as v(tbl, col, prefix, has_draft)
  loop
    execute format($f$
      with ranked as (
        select id, company_id,
               extract(year from created_at)::int as yr,
               row_number() over (
                 partition by company_id, extract(year from created_at)::int
                 order by created_at, id
               ) as rn
          from public.%1$I
         where %2$I is null %3$s
      ),
      base as (
        select company_id, year as yr, coalesce(max(next_value), 0) as start_at
          from public.reference_counters c
         where c.prefix = %4$L
         group by company_id, year
      )
      update public.%1$I t
         set %2$I = %4$L || '-' || r.yr || '-' ||
                    lpad((coalesce(b.start_at, 0) + r.rn)::text, 4, '0')
        from ranked r
        left join base b on b.company_id = r.company_id and b.yr = r.yr
       where t.id = r.id
    $f$, t.tbl, t.col, case when t.has_draft then 'and status <> ''draft''' else '' end, t.prefix);

    -- Move each counter past what the backfill just consumed, so the next
    -- insert does not collide with a backfilled number.
    execute format($f$
      insert into public.reference_counters (company_id, prefix, year, next_value)
      select company_id,
             %2$L,
             extract(year from created_at)::int,
             count(*)
        from public.%1$I
       where %3$I is not null
       group by company_id, extract(year from created_at)::int
      on conflict (company_id, prefix, year)
        do update set next_value = greatest(
             public.reference_counters.next_value, excluded.next_value)
    $f$, t.tbl, t.prefix, t.col);
  end loop;
end;
$$;

-- Give the demo/backfilled corrective actions a target date too, on the same
-- schedule the trigger uses for new rows.
update public.corrective_actions
   set due_date = created_at::date + case priority
                                       when 'critical' then 3
                                       when 'high'     then 7
                                       when 'medium'   then 14
                                       else 30
                                     end
 where due_date is null;

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_capa_due_date on public.corrective_actions;
--   drop trigger if exists trg_capa_action_code on public.corrective_actions;
--   drop trigger if exists trg_inspections_reference on public.inspections;
--   drop trigger if exists trg_incidents_reference on public.incidents;
--   drop trigger if exists trg_hazards_reference on public.hazards;
--   drop function if exists app.default_capa_due_date();
--   drop function if exists app.assign_reference();
--   drop function if exists app.next_reference(uuid, text, int);
--   drop table if exists public.reference_counters;
--   (assigned references are left in place; they are real identifiers by then)
-- ===========================================================================
