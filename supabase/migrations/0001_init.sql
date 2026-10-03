-- ============================================================================
-- Spring Hackathon — initial schema + RPCs
-- STATUS: PROPOSED — DO NOT APPLY AUTOMATICALLY.
-- Review this file, then apply MANUALLY via the Supabase SQL editor
-- (or `supabase db push` against a NON-production project first).
--
-- Guarantees implemented atomically in the database (never trust frontend):
--  1. One USN belongs to at most one team            (UNIQUE(team_members.usn))
--  2. Single Third-Year 5-member slot                (partial UNIQUE index)
--  3. Registration open/closed                       (checked inside RPC txn)
--  4. Team size / category / leader                  (checked inside RPC txn)
--  5. Server-generated IDs only                      (sequences, no client IDs)
--
-- USN policy: USNs are stored as UPPER(TRIM()) text. There is NO validity
-- table, NO validity check, NO year derivation anywhere in this schema.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

create table if not exists public.registration_settings (
  id integer primary key default 1,
  team_open boolean not null default true,
  mentor_open boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint settings_singleton check (id = 1)
);

insert into public.registration_settings (id, team_open, mentor_open)
values (1, true, true)
on conflict (id) do nothing;

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  registration_id text not null unique,
  team_name text not null check (char_length(trim(team_name)) between 1 and 120),
  category text not null check (category in ('Second Year', 'Third Year', 'Fourth Year')),
  member_count integer not null check (member_count between 4 and 5),
  created_at timestamptz not null default now(),
  constraint team_size_per_category check (
    (category = 'Second Year' and member_count = 4) or
    (category = 'Third Year' and member_count in (4, 5)) or
    (category = 'Fourth Year' and member_count = 4)
  )
);

-- ATOMIC Third-Year 5-member slot: at most ONE row may ever satisfy this
-- predicate. Concurrent transactions attempting a second 5-member Third Year
-- team block on / violate this index — no SELECT-then-INSERT race possible.
create unique index if not exists teams_one_third_year_five
  on public.teams ((1))
  where category = 'Third Year' and member_count = 5;

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  usn text not null check (char_length(trim(usn)) between 1 and 20),
  phone text not null check (char_length(trim(phone)) between 1 and 24),
  is_leader boolean not null default false
);

-- ATOMIC duplicate-USN protection: a USN can exist in at most one team, and
-- (combined with the in-RPC in-form check) at most once per team.
-- All USNs are normalized to UPPER(TRIM()) before insert (see RPC).
create unique index if not exists team_members_usn_unique on public.team_members (usn);

-- Exactly one leader per team.
create unique index if not exists team_members_one_leader
  on public.team_members (team_id)
  where is_leader = true;

create table if not exists public.mentors (
  id uuid primary key default gen_random_uuid(),
  registration_id text not null unique,
  name text not null check (char_length(trim(name)) between 1 and 100),
  email text not null check (char_length(trim(email)) between 3 and 320),
  phone text not null,
  department text,
  usn text,
  created_at timestamptz not null default now()
);

create unique index if not exists mentors_email_unique on public.mentors (lower(email));

-- Optional: also prevent the same USN registering as mentor twice (when given).
create unique index if not exists mentors_usn_unique
  on public.mentors (usn) where usn is not null;

-- Admin allow-list. First admin row must be inserted manually
-- (Supabase Dashboard → Table Editor) after creating the auth user:
--   insert into public.admin_users (user_id) values ('<auth.users.id>');
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Sequences for server-generated registration IDs (nextval() is atomic).
create sequence if not exists public.team_reg_seq start 1;
create sequence if not exists public.mentor_reg_seq start 1;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.mentors enable row level security;
alter table public.registration_settings enable row level security;
alter table public.admin_users enable row level security;

-- Public (anon) role: NO direct table access. All public writes go through
-- the SECURITY DEFINER RPCs below, which enforce every rule in-transaction.
-- (No policies for anon => no access.)

-- Authenticated admins (allow-listed) can read everything.
create policy if not exists teams_admin_read on public.teams
  for select to authenticated
  using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
create policy if not exists members_admin_read on public.team_members
  for select to authenticated
  using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
create policy if not exists mentors_admin_read on public.mentors
  for select to authenticated
  using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
create policy if not exists settings_admin_all on public.registration_settings
  for all to authenticated
  using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
  with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
create policy if not exists admin_users_self_read on public.admin_users
  for select to authenticated
  using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- RPCs (called by the frontend service layer — no raw table writes from UI)
-- ----------------------------------------------------------------------------

-- Read-only status; callable by anon + authenticated.
create or replace function public.get_registration_status()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'team_open', team_open,
    'mentor_open', mentor_open
  )
  from public.registration_settings where id = 1;
$$;

revoke all on function public.get_registration_status() from public;
grant execute on function public.get_registration_status() to anon, authenticated;

-- Admin-only status toggle. Frontend route protection is NOT sufficient;
-- the allow-list check here is authoritative.
create or replace function public.set_registration_status(p_team_open boolean, p_mentor_open boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  allowed boolean;
begin
  select exists (select 1 from public.admin_users a where a.user_id = auth.uid()) into allowed;
  if not allowed then
    raise exception 'Not authorized.' using errcode = '42501';
  end if;
  update public.registration_settings
    set team_open = p_team_open, mentor_open = p_mentor_open, updated_at = now()
    where id = 1;
  return public.get_registration_status();
end;
$$;

revoke all on function public.set_registration_status(boolean, boolean) from public;
grant execute on function public.set_registration_status(boolean, boolean) to authenticated;

-- Atomic team registration. Single transaction enforces, in order:
-- open flag → category/size/leader shape → in-form dupes → existing dupes
-- → insert (partial unique index guards the 5-member slot under concurrency).
create or replace function public.register_team(
  p_team_name text,
  p_category text,
  p_members jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_open boolean;
  v_count integer;
  v_leaders integer;
  v_usn text;
  v_seen text[] := '{}';
  v_member jsonb;
  v_team_id uuid;
  v_reg_id text;
begin
  select team_open into v_open from public.registration_settings where id = 1;
  if not coalesce(v_open, false) then
    raise exception 'Registrations are closed.' using errcode = 'P0001';
  end if;

  if p_category not in ('Second Year', 'Third Year', 'Fourth Year') then
    raise exception 'Invalid team category.' using errcode = '22023';
  end if;

  if p_team_name is null or char_length(trim(p_team_name)) = 0
     or char_length(trim(p_team_name)) > 120 then
    raise exception 'Invalid team name.' using errcode = '22023';
  end if;

  v_count := jsonb_array_length(p_members);

  if p_category = 'Second Year' and v_count <> 4 then
    raise exception 'Second Year teams must have exactly 4 members.' using errcode = '22023';
  elsif p_category = 'Fourth Year' and v_count <> 4 then
    raise exception 'Fourth Year teams must have exactly 4 members.' using errcode = '22023';
  elsif p_category = 'Third Year' and v_count not in (4, 5) then
    raise exception 'Third Year teams must have 4 members (5 only for the single 5-member slot).' using errcode = '22023';
  end if;

  select count(*) into v_leaders
  from jsonb_array_elements(p_members) m
  where coalesce((m.value ->> 'is_leader')::boolean, false) = true;
  if v_leaders <> 1 then
    raise exception 'Exactly one team leader is required.' using errcode = '22023';
  end if;

  -- Normalize + validate each member; reject in-form duplicate USNs.
  for v_member in select * from jsonb_array_elements(p_members) loop
    v_usn := upper(trim(v_member ->> 'usn'));
    if v_usn is null or v_usn = '' or char_length(v_usn) > 20 then
      raise exception 'Each member must have a USN (max 20 characters).' using errcode = '22023';
    end if;
    if v_usn = any (v_seen) then
      raise exception 'Duplicate USN within the same team: %.', v_usn using errcode = '23505';
    end if;
    v_seen := v_seen || v_usn;
    if coalesce(trim(v_member ->> 'name'), '') = '' then
      raise exception 'Each member must have a name.' using errcode = '22023';
    end if;
    if coalesce(trim(v_member ->> 'phone'), '') = '' then
      raise exception 'Each member must have a phone number.' using errcode = '22023';
    end if;
  end loop;

  -- Friendly pre-check for already-registered USNs. The UNIQUE index remains
  -- the authoritative guard under concurrency (a race raises 23505 there).
  if exists (select 1 from public.team_members tm where tm.usn = any (v_seen)) then
    raise exception 'A USN in this team is already registered with another team (duplicate USN).' using errcode = '23505';
  end if;

  v_reg_id := 'HACK-2026-' || lpad(nextval('public.team_reg_seq')::text, 3, '0');

  -- Insert the team row FIRST so the partial unique index adjudicates the
  -- Third-Year 5-member slot atomically under concurrency.
  insert into public.teams (registration_id, team_name, category, member_count)
  values (v_reg_id, trim(p_team_name), p_category, v_count)
  returning id into v_team_id;

  for v_member in select * from jsonb_array_elements(p_members) loop
    insert into public.team_members (team_id, name, usn, phone, is_leader)
    values (
      v_team_id,
      trim(v_member ->> 'name'),
      upper(trim(v_member ->> 'usn')),
      trim(v_member ->> 'phone'),
      coalesce((v_member ->> 'is_leader')::boolean, false)
    );
  end loop;

  return jsonb_build_object(
    'registration_id', v_reg_id,
    'team_id', v_team_id,
    'member_count', v_count
  );
exception
  when unique_violation then
    -- Covers: duplicate USN race, second 5-member-team race, reg-id collision.
    if exists (select 1 from public.teams t where t.category = 'Third Year' and t.member_count = 5) and v_count = 5 then
      raise exception 'The single Third Year 5-member slot has already been claimed.' using errcode = '23505';
    end if;
    raise exception 'Duplicate USN: a USN in this team is already registered.' using errcode = '23505';
end;
$$;

revoke all on function public.register_team(text, text, jsonb) from public;
grant execute on function public.register_team(text, text, jsonb) to anon, authenticated;

-- Atomic mentor registration. Duplicate e-mail (and optional USN) rejected.
create or replace function public.register_mentor(
  p_name text,
  p_email text,
  p_phone text,
  p_department text default null,
  p_usn text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_open boolean;
  v_usn text;
  v_reg_id text;
  v_id uuid;
begin
  select mentor_open into v_open from public.registration_settings where id = 1;
  if not coalesce(v_open, false) then
    raise exception 'Mentor registrations are closed.' using errcode = 'P0001';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'Name is required.' using errcode = '22023';
  end if;
  if p_email is null or trim(p_email) = '' then
    raise exception 'Email is required.' using errcode = '22023';
  end if;
  if p_phone is null or trim(p_phone) = '' then
    raise exception 'Phone is required.' using errcode = '22023';
  end if;

  v_usn := nullif(upper(trim(coalesce(p_usn, ''))), '');

  if exists (select 1 from public.mentors m where lower(m.email) = lower(trim(p_email))) then
    raise exception 'This email is already registered as a mentor.' using errcode = '23505';
  end if;
  if v_usn is not null and exists (select 1 from public.mentors m where m.usn = v_usn) then
    raise exception 'This USN is already registered as a mentor.' using errcode = '23505';
  end if;

  v_reg_id := 'MENTOR-2026-' || lpad(nextval('public.mentor_reg_seq')::text, 3, '0');

  insert into public.mentors (registration_id, name, email, phone, department, usn)
  values (trim(p_name), trim(p_email), trim(p_phone), nullif(trim(coalesce(p_department, ''))), v_usn)
  returning id into v_id;

  return jsonb_build_object('registration_id', v_reg_id, 'mentor_id', v_id);
end;
$$;

revoke all on function public.register_mentor(text, text, text, text, text) from public;
grant execute on function public.register_mentor(text, text, text, text, text) to anon, authenticated;
