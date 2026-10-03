// Central place for team-category + team-size rules.
// Mirrors the CHECK constraints enforced atomically by the database RPC.

export const TEAM_CATEGORIES = ['Second Year', 'Third Year']

export const TEAM_SIZES = {
  'Second Year': { min: 4, max: 4 },
  'Third Year': { min: 4, max: 5 },
}

/** Normalize a USN: trim + uppercase. No validity checking — registration data only. */
export function normalizeUSN(usn) {
  return String(usn ?? '').trim().toUpperCase()
}

/** Frontend phone check (format only). Backend does not reject on format. */
export function isValidPhone(phone) {
  const p = String(phone ?? '').trim()
  return /^[+\d][\d\s-]{6,17}$/.test(p)
}

export function validatePerson(person, label = 'Member') {
  const errors = []
  if (!person.name || !person.name.trim()) errors.push(`${label}: name is required.`)
  else if (person.name.trim().length > 100) errors.push(`${label}: name is too long (max 100).`)
  const usn = normalizeUSN(person.usn)
  if (!usn) errors.push(`${label}: USN is required.`)
  else if (usn.length > 20) errors.push(`${label}: USN is too long (max 20).`)
  if (!person.phone || !String(person.phone).trim()) errors.push(`${label}: phone is required.`)
  else if (!isValidPhone(person.phone)) errors.push(`${label}: phone format looks invalid.`)
  return errors
}

/**
 * Validate a full team form client-side.
 * - required fields, lengths, phone format, team size, in-form duplicate USNs
 * - NEVER checks USN validity / college membership / year derivation.
 */
export function validateTeamForm({ teamName, category, leader, members }) {
  const errors = []
  if (!teamName || !teamName.trim()) errors.push('Team name is required.')
  else if (teamName.trim().length > 120) errors.push('Team name is too long (max 120).')
  if (!TEAM_CATEGORIES.includes(category)) errors.push('Select a valid team category.')

  errors.push(...validatePerson(leader, 'Team Leader'))
  members.forEach((m, i) => errors.push(...validatePerson(m, `Member ${i + 2}`)))

  const total = 1 + members.length
  const rule = TEAM_SIZES[category]
  if (rule && (total < rule.min || total > rule.max)) {
    errors.push(
      `${category} teams must have ${rule.min === rule.max ? `exactly ${rule.min}` : `${rule.min}–${rule.max}`} members (including the leader).`,
    )
  }

  // Duplicate USNs within the same form (case-insensitive, trimmed).
  const seen = new Map()
  const all = [leader, ...members]
  all.forEach((p) => {
    const u = normalizeUSN(p.usn)
    if (!u) return
    seen.set(u, (seen.get(u) ?? 0) + 1)
  })
  const dupes = [...seen.entries()].filter(([, n]) => n > 1).map(([u]) => u)
  if (dupes.length > 0) {
    errors.push(`Duplicate USN within this team: ${dupes.join(', ')}. A USN cannot appear twice in the same team.`)
  }

  return { valid: errors.length === 0, errors }
}

/** Shape the wizard state into the payload expected by the register_team RPC. */
export function buildTeamPayload({ teamName, category, leader, members }) {
  const people = [leader, ...members].map((p, i) => ({
    name: String(p.name).trim(),
    usn: normalizeUSN(p.usn),
    phone: String(p.phone).trim(),
    is_leader: i === 0,
  }))
  return {
    p_team_name: teamName.trim(),
    p_category: category,
    p_members: people,
  }
}
