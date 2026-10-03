import { getSupabase } from '../lib/supabase.js'
import { buildTeamPayload } from '../lib/teamRules.js'

function friendlyError(err) {
  const msg = err?.message ?? String(err)
  if (/duplicate|already registered|unique/i.test(msg)) {
    return 'A USN in this team is already registered with another team. Each USN can belong to only one team.'
  }
  if (/five-member|5-member|slot/i.test(msg)) {
    return 'The single Third Year 5-member slot has already been claimed. Third Year teams must now have exactly 4 members.'
  }
  if (/closed/i.test(msg)) {
    return 'Registrations are currently closed.'
  }
  if (/size|members/i.test(msg)) {
    return msg
  }
  return msg || 'Registration failed. Please try again.'
}

export async function getRegistrationStatus() {
  const sb = getSupabase()
  const { data, error } = await sb.rpc('get_registration_status')
  if (error) throw new Error(error.message)
  // Expected: { team_open: bool, mentor_open: bool } or a single bool.
  if (typeof data === 'boolean') return { teamOpen: data, mentorOpen: data }
  return {
    teamOpen: data?.team_open ?? data?.teamOpen ?? true,
    mentorOpen: data?.mentor_open ?? data?.mentorOpen ?? true,
  }
}

export async function registerTeam(form) {
  const sb = getSupabase()
  const payload = buildTeamPayload(form)
  const { data, error } = await sb.rpc('register_team', payload)
  if (error) throw new Error(friendlyError(error))
  // Expected: { registration_id: 'HACK-2026-001', ... }
  return data
}

export async function registerMentor({ name, email, phone, department, usn }) {
  const sb = getSupabase()
  const { data, error } = await sb.rpc('register_mentor', {
    p_name: String(name).trim(),
    p_email: String(email).trim(),
    p_phone: String(phone).trim(),
    p_department: String(department ?? '').trim() || null,
    p_usn: usn ? String(usn).trim().toUpperCase() : null,
  })
  if (error) throw new Error(friendlyError(error))
  return data
}
