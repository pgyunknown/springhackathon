import { getSupabase } from '../lib/supabase.js'

// All admin reads go through RLS-protected tables / views.
// Service-role keys must never be used in the frontend.

export async function fetchTeamList({ search = '' } = {}) {
  const sb = getSupabase()
  let q = sb
    .from('teams')
    .select('id, registration_id, team_name, category, member_count, created_at')
    .order('created_at', { ascending: false })
    .limit(200)
  if (search.trim()) {
    q = q.or(
      `team_name.ilike.%${search.trim()}%,registration_id.ilike.%${search.trim()}%`,
    )
  }
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return data ?? []
}

export async function fetchTeamDetail(id) {
  const sb = getSupabase()
  const { data: team, error: tErr } = await sb
    .from('teams')
    .select('id, registration_id, team_name, category, member_count, created_at')
    .eq('id', id)
    .single()
  if (tErr) throw new Error(tErr.message)
  const { data: members, error: mErr } = await sb
    .from('team_members')
    .select('id, name, usn, phone, is_leader')
    .eq('team_id', id)
    .order('is_leader', { ascending: false })
  if (mErr) throw new Error(mErr.message)
  return { team, members: members ?? [] }
}

export async function fetchMentorList({ search = '' } = {}) {
  const sb = getSupabase()
  let q = sb
    .from('mentors')
    .select('id, registration_id, name, email, phone, department, usn, created_at')
    .order('created_at', { ascending: false })
    .limit(200)
  if (search.trim()) {
    const s = search.trim()
    q = q.or(`name.ilike.%${s}%,email.ilike.%${s}%,registration_id.ilike.%${s}%`)
  }
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return data ?? []
}

export async function fetchCounts() {
  const sb = getSupabase()
  const [teams, mentors] = await Promise.all([
    sb.from('teams').select('id, category, member_count', { count: 'exact' }),
    sb.from('mentors').select('id', { count: 'exact' }),
  ])
  if (teams.error) throw new Error(teams.error.message)
  if (mentors.error) throw new Error(mentors.error.message)
  const byCategory = {}
  for (const t of teams.data ?? []) {
    byCategory[t.category] = (byCategory[t.category] ?? 0) + 1
  }
  return {
    teamCount: teams.count ?? 0,
    mentorCount: mentors.count ?? 0,
    byCategory,
  }
}

export async function getSettings() {
  const sb = getSupabase()
  const { data, error } = await sb.rpc('get_registration_status')
  if (error) throw new Error(error.message)
  if (typeof data === 'boolean') return { teamOpen: data, mentorOpen: data }
  return {
    teamOpen: data?.team_open ?? true,
    mentorOpen: data?.mentor_open ?? true,
  }
}

export async function setSettings({ teamOpen, mentorOpen }) {
  const sb = getSupabase()
  const { data, error } = await sb.rpc('set_registration_status', {
    p_team_open: teamOpen,
    p_mentor_open: mentorOpen,
  })
  if (error) throw new Error(error.message)
  return data
}
