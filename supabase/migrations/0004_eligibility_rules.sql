-- ============================================================================
-- Spring Hackathon — 0004 eligibility correction (NEW Supabase project)
-- STATUS: PROPOSED — DO NOT APPLY without human approval. Apply ONLY via
-- the NEW project's SQL Editor, AFTER verifying: teams/mentors row counts
-- are 0 (no stranded Fourth Year teams possible), and BEFORE/AFTER only
-- with the matching frontend update (DB first, then frontend same window).
-- NEVER run `supabase db push` blindly.
--
-- Scope (approved design):
--  1. Team categories reduced to Second Year + Third Year (Fourth removed).
--  2. New server-side-only mentor_eligibility table (57 authoritative
--     Seventh-Semester USNs, NOTHING else — no names, no year/semester).
--  3. register_mentor() enforces eligibility; register_team() drops Fourth.
--  4. No changes to RLS/policies/grants on existing objects, sequences,
--     registration-ID generation, duplicate protections, or settings.
--  5. 0001/0002/0003 are never modified by this file.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Fail-safe pre-checks: abort with a clear message instead of assuming
-- the expected empty state.
-- ----------------------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.teams WHERE category = 'Fourth Year') THEN
    RAISE EXCEPTION 'Fourth Year teams exist; manual reconciliation required before removing the category.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.teams WHERE category NOT IN ('Second Year', 'Third Year')) THEN
    RAISE EXCEPTION 'Teams with unknown categories exist; manual reconciliation required.';
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 1. mentor_eligibility: USN-only eligibility dataset.
-- RLS enabled, ZERO policies (invisible to every API role), privileges
-- revoked. Sole reader: SECURITY DEFINER register_mentor().
-- ----------------------------------------------------------------------------

CREATE TABLE public.mentor_eligibility (
  usn text PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  note text NULL
);

ALTER TABLE public.mentor_eligibility ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.mentor_eligibility FROM anon, authenticated, PUBLIC;

-- Authoritative Seventh-Semester list: EXACTLY these 57 USNs, stored as
-- UPPER(TRIM()). No names, semesters, years, phones, or emails stored here.
INSERT INTO public.mentor_eligibility (usn) VALUES
  ('4MC23CB001'),
  ('4MC23CB002'),
  ('4MC23CB003'),
  ('4MC23CB005'),
  ('4MC23CB006'),
  ('4MC23CB007'),
  ('4MC23CB008'),
  ('4MC23CB009'),
  ('4MC23CB010'),
  ('4MC23CB011'),
  ('4MC23CB013'),
  ('4MC23CB014'),
  ('4MC23CB015'),
  ('4MC23CB016'),
  ('4MC23CB017'),
  ('4MC23CB018'),
  ('4MC23CB019'),
  ('4MC23CB020'),
  ('4MC23CB021'),
  ('4MC23CB023'),
  ('4MC23CB024'),
  ('4MC23CB025'),
  ('4MC23CB026'),
  ('4MC23CB027'),
  ('4MC23CB028'),
  ('4MC23CB029'),
  ('4MC23CB030'),
  ('4MC23CB032'),
  ('4MC23CB033'),
  ('4MC23CB034'),
  ('4MC23CB035'),
  ('4MC23CB036'),
  ('4MC23CB039'),
  ('4MC23CB040'),
  ('4MC23CB042'),
  ('4MC23CB043'),
  ('4MC23CB044'),
  ('4MC23CB045'),
  ('4MC23CB046'),
  ('4MC23CB049'),
  ('4MC23CB050'),
  ('4MC23CB051'),
  ('4MC23CB052'),
  ('4MC23CB053'),
  ('4MC23CB054'),
  ('4MC23CB055'),
  ('4MC23CB057'),
  ('4MC23CB060'),
  ('4MC23CB061'),
  ('4MC23CB062'),
  ('4MC23CB063'),
  ('4MC23CB064'),
  ('4MC24CB400'),
  ('4MC24CB401'),
  ('4MC24CB402'),
  ('4MC24CB403'),
  ('4MC24CB404');

-- ----------------------------------------------------------------------------
-- 2. teams category/size constraints: Fourth Year becomes impossible.
-- The partial unique index teams_one_third_year_five is UNCHANGED
-- (its predicate is already Third-Year-specific).
-- ----------------------------------------------------------------------------

ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_category_check;
ALTER TABLE public.teams
  ADD CONSTRAINT teams_category_check
  CHECK (category IN ('Second Year', 'Third Year'));

ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_size_per_category;
ALTER TABLE public.teams
  ADD CONSTRAINT teams_size_per_category
  CHECK (
    (category = 'Second Year' AND member_count = 4) OR
    (category = 'Third Year'  AND member_count IN (4, 5))
  );

-- teams_member_count_check (4..5) is unchanged and still correct.

-- ----------------------------------------------------------------------------
-- 3. register_team(): accept only Second/Third Year. All other behavior
-- (sizes, leader, duplicates, IDs) is byte-identical to 0003.
-- ----------------------------------------------------------------------------

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

  IF p_category NOT IN ('Second Year', 'Third Year') THEN
    RAISE EXCEPTION 'Invalid team category.' USING errcode = '22023';
  END IF;

  IF p_team_name IS NULL OR char_length(trim(p_team_name)) = 0
     OR char_length(trim(p_team_name)) > 120 THEN
    RAISE EXCEPTION 'Invalid team name.' USING errcode = '22023';
  END IF;

  v_count := jsonb_array_length(p_members);

  IF p_category = 'Second Year' AND v_count <> 4 THEN
    RAISE EXCEPTION 'Second Year teams must have exactly 4 members.' USING errcode = '22023';
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

  IF EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.usn = ANY (v_seen)) THEN
    RAISE EXCEPTION 'A USN in this team is already registered with another team (duplicate USN).' USING errcode = '23505';
  END IF;

  v_reg_id := 'HACK-2026-' || lpad(nextval('public.team_reg_seq')::text, 3, '0');

  INSERT INTO public.teams (registration_id, team_name, category, member_count)
  VALUES (v_reg_id, trim(p_team_name), p_category, v_count)
  RETURNING id INTO v_team_id;

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

-- ----------------------------------------------------------------------------
-- 4. register_mentor(): enforce Seventh-Semester eligibility server-side.
-- Order: presence -> eligibility -> duplicates -> insert. One generic
-- eligibility message (no valid/invalid oracle, no dataset exposure).
-- Duplicate email/USN protection and ID generation are unchanged.
-- ----------------------------------------------------------------------------

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

  -- Eligibility gate: USN must be present AND on the Seventh-Semester list.
  -- A missing USN can never bypass this check.
  IF v_usn IS NULL THEN
    RAISE EXCEPTION 'USN is required to verify mentor eligibility.' USING errcode = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mentor_eligibility e WHERE e.usn = v_usn) THEN
    RAISE EXCEPTION 'This USN is not eligible for mentor registration.' USING errcode = '23505';
  END IF;

  IF EXISTS (SELECT 1 FROM public.mentors m WHERE lower(m.email) = lower(trim(p_email))) THEN
    RAISE EXCEPTION 'This email is already registered as a mentor.' USING errcode = '23505';
  END IF;
  IF EXISTS (SELECT 1 FROM public.mentors m WHERE m.usn = v_usn) THEN
    RAISE EXCEPTION 'This USN is already registered as a mentor.' USING errcode = '23505';
  END IF;

  v_reg_id := 'MENTOR-2026-' || lpad(nextval('public.mentor_reg_seq')::text, 3, '0');

  INSERT INTO public.mentors (registration_id, name, email, phone, department, usn)
  VALUES (
    v_reg_id,
    trim(p_name),
    trim(p_email),
    trim(p_phone),
    NULLIF(trim(COALESCE(p_department, ''))),
    v_usn
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('registration_id', v_reg_id, 'mentor_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.register_mentor(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_mentor(text, text, text, text, text) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- ROLLBACK SKETCH (reference only — capture current RPC bodies via
-- pg_get_functiondef BEFORE applying):
--  1. Restore prior register_team / register_mentor bodies from capture.
--  2. Re-add 'Fourth Year' to teams_category_check and the Fourth Year
--     branch of teams_size_per_category.
--  3. DELETE FROM public.mentor_eligibility; DROP TABLE public.mentor_eligibility.
-- Sequences untouched by DDL need no reset unless registrations succeeded.
-- ============================================================================
