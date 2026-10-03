-- ============================================================================
-- Spring Hackathon — 0003 FRESH initial schema (NEW Supabase project)
-- STATUS: PROPOSED — DO NOT APPLY until the new project is verified empty
-- and its URL matches the configured VITE_SUPABASE_URL. Apply ONLY via the
-- new project's SQL Editor. NEVER run `supabase db push` blindly.
--
-- Source of truth: approved NEW SUPABASE — INITIAL SCHEMA DESIGN REPORT.
-- 0001_init.sql and 0002_in_place_delta.sql are ABANDONED (old database) and
-- MUST NEVER be applied to the new project.
--
-- Design summary:
--  - No valid_usns, no year/semester columns, no registration_open column,
--    no validation RPCs, no student reference tables.
--  - BIGINT identity primary keys (no UUID PKs except admin_users.user_id,
--    which must match auth.users.id).
--  - Duplicate-USN protection: global UNIQUE(team_members.usn).
--  - Single Third-Year 5-member slot: partial unique index (concurrency-safe).
--  - Registration IDs via dedicated sequences (first success => ...-001).
--  - Anon role: NO direct table access. All writes via SECURITY DEFINER
--    RPCs with fixed search_path. Admin reads via auth + allow-list RLS.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

CREATE TABLE public.registration_settings (
  id integer PRIMARY KEY DEFAULT 1,
  team_open boolean NOT NULL DEFAULT TRUE,
  mentor_open boolean NOT NULL DEFAULT TRUE,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT settings_singleton CHECK (id = 1)
);

INSERT INTO public.registration_settings (id, team_open, mentor_open)
VALUES (1, TRUE, TRUE)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE public.teams (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  registration_id text NOT NULL,
  team_name text NOT NULL,
  category text NOT NULL,
  member_count integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT teams_name_check CHECK (
    char_length(trim(team_name)) BETWEEN 1 AND 120
  ),
  CONSTRAINT teams_category_check CHECK (
    category IN ('Second Year', 'Third Year', 'Fourth Year')
  ),
  CONSTRAINT teams_member_count_check CHECK (
    member_count BETWEEN 4 AND 5
  ),
  CONSTRAINT teams_size_per_category CHECK (
    (category = 'Second Year' AND member_count = 4) OR
    (category = 'Third Year'  AND member_count IN (4, 5)) OR
    (category = 'Fourth Year' AND member_count = 4)
  )
);

CREATE UNIQUE INDEX teams_registration_id_unique
  ON public.teams (registration_id);

-- Atomic single Third-Year 5-member slot: at most ONE row may ever satisfy
-- this predicate. Concurrent claimants serialize on this index.
CREATE UNIQUE INDEX teams_one_third_year_five
  ON public.teams ((1))
  WHERE category = 'Third Year' AND member_count = 5;

CREATE TABLE public.team_members (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_id bigint NOT NULL REFERENCES public.teams (id) ON DELETE CASCADE,
  name text NOT NULL,
  usn text NOT NULL,
  phone text NOT NULL,
  is_leader boolean NOT NULL DEFAULT FALSE,
  CONSTRAINT team_members_name_check CHECK (
    char_length(trim(name)) BETWEEN 1 AND 100
  ),
  CONSTRAINT team_members_usn_check CHECK (
    char_length(trim(usn)) BETWEEN 1 AND 20
  ),
  CONSTRAINT team_members_phone_check CHECK (
    char_length(trim(phone)) BETWEEN 1 AND 24
  )
);

-- Atomic duplicate-USN protection: one USN belongs to at most one team
-- globally. USNs are stored as UPPER(TRIM()) text (see RPCs); no validity
-- table, no lookup, no year derivation exists anywhere in this schema.
CREATE UNIQUE INDEX team_members_usn_unique
  ON public.team_members (usn);

-- Exactly one leader per team.
CREATE UNIQUE INDEX team_members_one_leader
  ON public.team_members (team_id)
  WHERE is_leader = TRUE;

CREATE TABLE public.mentors (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  registration_id text NOT NULL,
  name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  department text,
  usn text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mentors_name_check CHECK (
    char_length(trim(name)) BETWEEN 1 AND 100
  )
);

CREATE UNIQUE INDEX mentors_registration_id_unique
  ON public.mentors (registration_id);

CREATE UNIQUE INDEX mentors_email_unique
  ON public.mentors (lower(email));

CREATE UNIQUE INDEX mentors_usn_unique
  ON public.mentors (usn)
  WHERE usn IS NOT NULL;

-- Admin allow-list. No passwords stored here; identity comes from Supabase
-- Auth. First row is inserted manually after creating the auth user.
CREATE TABLE public.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Dedicated registration-ID sequences. nextval() is atomic; the first
-- nextval() on each yields 1, hence ...-001 for the first success.
CREATE SEQUENCE public.team_reg_seq START 1;
CREATE SEQUENCE public.mentor_reg_seq START 1;

-- ----------------------------------------------------------------------------
-- Row Level Security: anon gets NO direct table access. Authenticated
-- allow-listed admins can read; settings mutation goes through the RPC.
-- ----------------------------------------------------------------------------

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registration_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY teams_admin_read ON public.teams
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = auth.uid()));

CREATE POLICY members_admin_read ON public.team_members
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = auth.uid()));

CREATE POLICY mentors_admin_read ON public.mentors
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = auth.uid()));

CREATE POLICY settings_admin_all ON public.registration_settings
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = auth.uid()));

CREATE POLICY admin_users_self_read ON public.admin_users
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- RPCs: the ONLY write path for public registration. No raw table writes.
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
    SELECT 1 FROM public.admin_users a WHERE a.user_id = auth.uid()
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

  -- Friendly pre-check; the UNIQUE(team_members.usn) index remains the
  -- authoritative guard under concurrency (a race raises 23505 below).
  IF EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.usn = ANY (v_seen)) THEN
    RAISE EXCEPTION 'A USN in this team is already registered with another team (duplicate USN).' USING errcode = '23505';
  END IF;

  v_reg_id := 'HACK-2026-' || lpad(nextval('public.team_reg_seq')::text, 3, '0');

  -- Team row first so the partial unique index adjudicates the Third-Year
  -- 5-member slot atomically under concurrency.
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
