# Spring Hackathon

Branch-level hackathon registration system (React + Vite + Tailwind + React Router + Supabase).

## Routes

- `/` — landing (Register Team / Mentor Registration / Admin Access)
- `/register/team` — team registration wizard (all steps on this one URL)
- `/register/mentor` — mentor registration
- `/admin/login` — admin sign-in (Supabase Auth)
- `/admin/dashboard`, `/admin/teams`, `/admin/teams/:id`, `/admin/mentors`, `/admin/settings`

## Setup

1. Copy env: `cp .env.example .env` and fill `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`
   (anon key only — never the service-role key).
2. **Database (manual step, requires approval):** review
   `supabase/migrations/0001_init.sql`, then apply it via the Supabase SQL
   editor against a non-production project first. Do NOT run `supabase db push`
   against production.
3. Create an admin auth user (Supabase Dashboard → Authentication), then allow-list it:
   `insert into public.admin_users (user_id) values ('<auth.users.id>');`
4. `npm install && npm run dev`

## Key rules

- **USN validation: REMOVED.** USNs are stored as `UPPER(TRIM())` text only.
  No validity lookup, no year/semester derivation, no valid/invalid messaging.
- **Duplicate-USN protection: REQUIRED** and enforced atomically by
  `UNIQUE(team_members.usn)` + checks inside `register_team`.
- Team sizes: Second Year exactly 4 · Third Year 4 (exactly ONE 5-member slot,
  enforced by partial unique index `teams_one_third_year_five`) · Fourth Year
  exactly 4. Category is explicitly selected, never derived from USN.
- Registration IDs (`HACK-2026-001`, `MENTOR-2026-001`) are generated
  server-side via sequences and returned by the RPC — never in React.
- All DB access lives in `src/services/`; pages/components contain no raw SQL.
