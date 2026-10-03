-- ============================================================================
-- Spring Hackathon — 0002 controlled IN-PLACE DELTA migration
-- STATUS: PROPOSED — DO NOT APPLY. FOR REVIEW ONLY.
-- DO NOT run `supabase db push`. DO NOT paste into the SQL Editor yet.
--
-- Basis: verified live schema (admin_users, mentors, registration_settings,
-- team_members, teams, valid_usns; BIGINT ids; existing sequences
-- team_registration_seq / mentor_registration_seq, never used; 0
-- teams/team_members/mentors rows) + read-only anon probes confirming:
--   - registration_settings.registration_open EXISTS (1 row, anon-readable)
--   - teams.category ABSENT, mentors.email ABSENT,
--     registration_settings.team_open/mentor_open ABSENT
--   - team_members exposes id, team_id, name, usn, phone, is_leader, year,
--     semester (parse succeeded; RLS denies anon execution)
--   - anon is denied on teams / team_members / mentors / admin_users
--   - get_registration_status() does NOT exist live (PGRST202)
--
-- This file REPLACES the approach of 0001_init.sql for the live project.
-- 0001_init.sql MUST NEVER be applied to the live database (UUID ids,
-- admin_users(user_id), wrong sequence names, CREATE POLICY IF NOT EXISTS).
--
-- PRE-APPLY CHECKLIST (all read-only, via SQL Editor by a human reviewer):
--  1. \d teams / mentors / team_members / registration_settings / admin_users
--  2. pg_get_functiondef() capture of register_team, register_mentor,
--     set_registration_status, validate_usn, validate_team_usns (ROLLBACK
--     MATERIAL — Step 2 of Gate 2A could not capture these via anon access)
--  3. Confirm sequence positions (SELECT last_value, is_called FROM
--     team_registration_seq / mentor_registration_seq) — expect start state
--  4. Confirm counts: teams=0, team_members=0, mentors=0
--  5. Confirm team_members.year / semester are NULLABLE (new RPC omits them)
--  6. Confirm no consumer besides this app calls validate_* RPCs
--
-- DESIGN NOTES:
--  - BIGINT ids, PKs, FKs, existing indexes: preserved, never touched.
--  - valid_usns + validate_usn + validate_team_usns: never referenced here,
--    never dropped. Separate cleanup decision.
--  - No RLS policy is created, altered, or dropped here (PostgreSQL has no
--    CREATE POLICY IF NOT EXISTS). Existing policies stay exactly as-is.
--  - Every data-dependent step FAILS SAFE (RAISE EXCEPTION, full rollback)
--    instead of assuming the 0-row state.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A. teams: add category + member_count (+ checks, NOT NULL once proven empty
--    of violations). Existing registration_id / team_name columns untouched.
-- ----------------------------------------------------------------------------

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS category text;

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS member_count integer;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.teams
    WHERE category IS NULL
       OR member_count IS NULL
       OR NOT (
         (category = 'Second Year'  AND member_count = 4) OR
         (category = 'Third Year'   AND member_count IN (4, 5)) OR
         (category = 'Fourth Year'  AND member_count = 4)
       )
  ) THEN
    RAISE EXCEPTION 'teams contains rows violating the category/size rules; manual reconciliation required.';
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'teams_category_check'
  ) THEN
    ALTER TABLE public.teams
      ADD CONSTRAINT teams_category_check
      CHECK (category IN ('Second Year', 'Third Year', 'Fourth Year'));
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'teams_member_count_check'
  ) THEN
    ALTER TABLE public.teams
      ADD CONSTRAINT teams_member_count_check
      CHECK (member_count BETWEEN 4 AND 5);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'teams_size_per_category'
  ) THEN
    ALTER TABLE public.teams
      ADD CONSTRAINT teams_size_per_category
      CHECK (
        (category = 'Second Year' AND member_count = 4) OR
        (category = 'Third Year'  AND member_count IN (4, 5)) OR
        (category = 'Fourth Year' AND member_count = 4)
      );
  END IF;
END;
$$;

ALTER TABLE public.teams ALTER COLUMN category SET NOT NULL;
ALTER TABLE public.teams ALTER COLUMN member_count SET NOT NULL;

-- teams.registration_id: keep the existing column; guarantee uniqueness +
-- presence going forward. Fails safe if live data violates either.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.teams WHERE registration_id IS NULL) THEN
    RAISE EXCEPTION 'teams.registration_id contains NULLs; manual reconciliation required.';
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS teams_registration_id_unique
  ON public.teams (registration_id);

ALTER TABLE public.teams ALTER COLUMN registration_id SET NOT NULL;

-- E. Atomic single Third-Year 5-member slot (partial unique index).
-- Concurrent second 5-member Third-Year inserts block/violate here.
CREATE UNIQUE INDEX IF NOT EXISTS teams_one_third_year_five
  ON public.teams ((1))
  WHERE category = 'Third Year' AND member_count = 5;

-- ----------------------------------------------------------------------------
-- B. mentors: add registration_id + email + department.
-- Table is empty per audit; every step still fails safe if it is not.
-- ----------------------------------------------------------------------------

ALTER TABLE public.mentors
  ADD COLUMN IF NOT EXISTS registration_id text;

ALTER TABLE public.mentors
  ADD COLUMN IF NOT EXISTS email text;

ALTER TABLE public.mentors
  ADD COLUMN IF NOT EXISTS department text;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.mentors WHERE registration_id IS NULL) THEN
    RAISE EXCEPTION 'mentors.registration_id contains NULLs; manual reconciliation required.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.mentors WHERE email IS NULL) THEN
    RAISE EXCEPTION 'mentors.email contains NULLs; manual reconciliation required.';
  END IF;
  IF EXISTS (
    SELECT lower(email) FROM public.mentors
    GROUP BY lower(email) HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'mentors contains duplicate emails (case-insensitive); manual reconciliation required.';
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS mentors_registration_id_unique
  ON public.mentors (registration_id);

-- Case-insensitive unique email, as required by mentor registration.
CREATE UNIQUE INDEX IF NOT EXISTS mentors_email_unique
  ON public.mentors (lower(email));

ALTER TABLE public.mentors ALTER COLUMN registration_id SET NOT NULL;
ALTER TABLE public.mentors ALTER COLUMN email SET NOT NULL;

-- mentors.usn unique index + team_members.usn global unique index +
-- unique leader index: EXISTING, preserved, never touched here.

-- ----------------------------------------------------------------------------
-- C. registration_settings: add team_open / mentor_open, backfill from
-- registration_open. registration_open is RETAINED (not dropped).
-- ----------------------------------------------------------------------------

ALTER TABLE public.registration_settings
  ADD COLUMN IF NOT EXISTS team_open boolean;

ALTER TABLE public.registration_settings
  ADD COLUMN IF NOT EXISTS mentor_open boolean;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.registration_settings) <> 1 THEN
    RAISE EXCEPTION 'registration_settings must contain exactly one row.';
  END IF;
END;
$$;

UPDATE public.registration_settings
SET team_open   = COALESCE(team_open, registration_open, TRUE),
    mentor_open = COALESCE(mentor_open, registration_open, TRUE)
WHERE id = 1 AND (team_open IS NULL OR mentor_open IS NULL);

ALTER TABLE public.registration_settings ALTER COLUMN team_open SET NOT NULL;
ALTER TABLE public.registration_settings ALTER COLUMN mentor_open SET NOT NULL;

-- ----------------------------------------------------------------------------
-- D. Registration RPCs — exact frontend-compatible contracts.
-- SECURITY DEFINER, fixed search_path, admin_users(id) allow-list,
-- EXISTING sequence names, UPPER(TRIM()) USN normalization,
-- NO reference to valid_usns / validate_usn / validate_team_usns.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_registration_status()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'team_open', team_open,
    'mentor_open', mentor_open
  )
  FROM public.registration_settings WHERE id = 1;
$$;

REVOKE ALL ON FUNCTION public.get_registration_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_registration_status() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_registration_status(
  p_team_open boolean,
  p_mentor_open boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users a WHERE a.id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized.' USING errcode = '42501';
  END IF;
  UPDATE public.registration_settings
  SET team_open = p_team_open,
      mentor_open = p_mentor_open,
      updated_at = now()
  WHERE id = 1;
  RETURN public.get_registration_status();
END;
$$;

REVOKE ALL ON FUNCTION public.set_registration_status(boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_registration_status(boolean, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.register_team(
  p_team_name text,
  p_category text,
  p_members jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_open boolean;
  v_count integer;
  v_leaders integer;
  v_usn text;
  v_seen text[] := '{}';
  v_member jsonb;
  v_team_id bigint;
  v_reg_id text;
BEGIN
  SELECT team_open INTO v_open FROM public.registration_settings WHERE id = 1;
  IF NOT COALESCE(v_open, FALSE) THEN
    RAISE EXCEPTION 'Registrations are closed.' USING errcode = 'P0001';
  END IF;

  IF p_category NOT IN ('Second Year', 'Third Year', 'Fourth Year') THEN
    RAISE EXCEPTION 'Invalid team category.' USING errcode = '22023';
  END IF;

  IF p_team_name IS NULL OR char_length(trim(p_team_name)) = 0
     OR char_length(trim(p_team_name)) > 120 THEN
    RAISE EXCEPTION 'Invalid team name.' USING errcode = '22023';
  END IF;

  v_count := jsonb_array_length(p_members);

  IF p_category = 'Second Year' AND v_count <> 4 THEN
    RAISE EXCEPTION 'Second Year teams must have exactly 4 members.' USING errcode = '22023';
  ELSIF p_category = 'Fourth Year' AND v_count <> 4 THEN
    RAISE EXCEPTION 'Fourth Year teams must have exactly 4 members.' USING errcode = '22023';
  ELSIF p_category = 'Third Year' AND v_count NOT IN (4, 5) THEN
    RAISE EXCEPTION 'Third Year teams must have 4 members (5 only for the single 5-member slot).' USING errcode = '22023';
  END IF;

  SELECT count(*) INTO v_leaders
  FROM jsonb_array_elements(p_members) m
  WHERE COALESCE((m.value ->> 'is_leader')::boolean, FALSE) = TRUE;
  IF v_leaders <> 1 THEN
    RAISE EXCEPTION 'Exactly one team leader is required.' USING errcode = '22023';
  END IF;

  FOR v_member IN SELECT * FROM jsonb_array_elements(p_members) LOOP
    v_usn := upper(trim(v_member ->> 'usn'));
    IF v_usn IS NULL OR v_usn = '' OR char_length(v_usn) > 20 THEN
      RAISE EXCEPTION 'Each member must have a USN (max 20 characters).' USING errcode = '22023';
    END IF;
    IF v_usn = ANY (v_seen) THEN
      RAISE EXCEPTION 'Duplicate USN within the same team: %.', v_usn USING errcode = '23505';
    END IF;
    v_seen := v_seen || v_usn;
    IF COALESCE(trim(v_member ->> 'name'), '') = '' THEN
      RAISE EXCEPTION 'Each member must have a name.' USING errcode = '22023';
    END IF;
    IF COALESCE(trim(v_member ->> 'phone'), '') = '' THEN
      RAISE EXCEPTION 'Each member must have a phone number.' USING errcode = '22023';
    END IF;
  END LOOP;

  -- Friendly pre-check; the existing UNIQUE(team_members.usn) index remains
  -- the authoritative guard under concurrency (a race raises 23505 below).
  IF EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.usn = ANY (v_seen)) THEN
    RAISE EXCEPTION 'A USN in this team is already registered with another team (duplicate USN).' USING errcode = '23505';
  END IF;

  -- Existing sequence: never generated a value, so first nextval() yields 1.
  v_reg_id := 'HACK-2026-' || lpad(nextval('public.team_registration_seq')::text, 3, '0');

  -- Team row first so the partial unique index adjudicates the Third-Year
  -- 5-member slot atomically under concurrency.
  INSERT INTO public.teams (registration_id, team_name, category, member_count)
  VALUES (v_reg_id, trim(p_team_name), p_category, v_count)
  RETURNING id INTO v_team_id;

  -- year/semester intentionally omitted (registration data only, unused).
  FOR v_member IN SELECT * FROM jsonb_array_elements(p_members) LOOP
    INSERT INTO public.team_members (team_id, name, usn, phone, is_leader)
    VALUES (
      v_team_id,
      trim(v_member ->> 'name'),
      upper(trim(v_member ->> 'usn')),
      trim(v_member ->> 'phone'),
      COALESCE((v_member ->> 'is_leader')::boolean, FALSE)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'registration_id', v_reg_id,
    'team_id', v_team_id,
    'member_count', v_count
  );
EXCEPTION
  WHEN unique_violation THEN
    IF EXISTS (
      SELECT 1 FROM public.teams t
      WHERE t.category = 'Third Year' AND t.member_count = 5
    ) AND v_count = 5 THEN
      RAISE EXCEPTION 'The single Third Year 5-member slot has already been claimed.' USING errcode = '23505';
    END IF;
    RAISE EXCEPTION 'Duplicate USN: a USN in this team is already registered.' USING errcode = '23505';
END;
$$;

REVOKE ALL ON FUNCTION public.register_team(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_team(text, text, jsonb) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.register_mentor(
  p_name text,
  p_email text,
  p_phone text,
  p_department text DEFAULT NULL,
  p_usn text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_open boolean;
  v_usn text;
  v_reg_id text;
  v_id bigint;
BEGIN
  SELECT mentor_open INTO v_open FROM public.registration_settings WHERE id = 1;
  IF NOT COALESCE(v_open, FALSE) THEN
    RAISE EXCEPTION 'Mentor registrations are closed.' USING errcode = 'P0001';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'Name is required.' USING errcode = '22023';
  END IF;
  IF p_email IS NULL OR trim(p_email) = '' THEN
    RAISE EXCEPTION 'Email is required.' USING errcode = '22023';
  END IF;
  IF p_phone IS NULL OR trim(p_phone) = '' THEN
    RAISE EXCEPTION 'Phone is required.' USING errcode = '22023';
  END IF;

  v_usn := NULLIF(upper(trim(COALESCE(p_usn, ''))), '');

  IF EXISTS (SELECT 1 FROM public.mentors m WHERE lower(m.email) = lower(trim(p_email))) THEN
    RAISE EXCEPTION 'This email is already registered as a mentor.' USING errcode = '23505';
  END IF;
  IF v_usn IS NOT NULL AND EXISTS (SELECT 1 FROM public.mentors m WHERE m.usn = v_usn) THEN
    RAISE EXCEPTION 'This USN is already registered as a mentor.' USING errcode = '23505';
  END IF;

  v_reg_id := 'MENTOR-2026-' || lpad(nextval('public.mentor_registration_seq')::text, 3, '0');

  INSERT INTO public.mentors (registration_id, name, email, phone, department, usn)
  VALUES (
    v_reg_id,
    trim(p_name),
    trim(p_email),
    trim(p_phone),
    NULLIF(trim(COALESCE(p_department, '')), ''),
    v_usn
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('registration_id', v_reg_id, 'mentor_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.register_mentor(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_mentor(text, text, text, text, text) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- ROLLBACK SKETCH (reference only — capture live definitions FIRST, Gate 2A
-- Step 2, via pg_get_functiondef in the SQL Editor BEFORE applying):
--   1. Restore prior bodies of get_registration_status /
--      set_registration_status / register_team / register_mentor from the
--      captured definitions (or DROP the three that did not exist live:
--      get_registration_status at minimum is new — PGRST202 confirmed).
--   2. DROP INDEX IF EXISTS teams_one_third_year_five;
--   3. DROP INDEX IF EXISTS mentors_registration_id_unique;
--   4. DROP INDEX IF EXISTS mentors_email_unique;
--   5. DROP INDEX IF EXISTS teams_registration_id_unique;  -- only if this
--      migration created it (verify pre-apply whether it already existed)
--   6. ALTER TABLE ... DROP CONSTRAINT IF EXISTS teams_category_check,
--      teams_member_count_check, teams_size_per_category;
--   7. ALTER TABLE teams DROP COLUMN IF EXISTS category, DROP COLUMN IF EXISTS
--      member_count; ALTER TABLE mentors DROP COLUMN IF EXISTS
--      registration_id, email, department; ALTER TABLE registration_settings
--      DROP COLUMN IF EXISTS team_open, mentor_open.
--   8. Sequences were never advanced by DDL; no reset needed unless a
--      registration succeeded post-apply (then reconciliation, not rollback).
-- valid_usns, validate_* RPCs, existing policies, BIGINT ids: untouched by
-- this migration, so they need no rollback path.
-- ============================================================================
