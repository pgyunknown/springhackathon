import { useMemo, useState } from 'react'
import {
  Button,
  Input,
  Loading,
  MemberCard,
  PageContainer,
  Select,
  StepIndicator,
  USNInput,
} from '../components/ui.jsx'
import { TEAM_CATEGORIES, TEAM_SIZES, normalizeUSN, validateTeamForm } from '../lib/teamRules.js'
import { getRegistrationStatus, registerTeam } from '../services/publicService.js'
import { useEffect } from 'react'

const STEPS = ['Team Details', 'Team Leader', 'Team Members', 'Review', 'Success']
const emptyPerson = () => ({ name: '', usn: '', phone: '' })

function expectedCount(category, members) {
  // Show contextual hint: Third Year allows a 5th member only if slot free.
  // The backend is authoritative; frontend never pre-checks slot availability.
  const rule = TEAM_SIZES[category]
  if (!rule) return ''
  if (rule.min === rule.max) return `Exactly ${rule.min} members (including leader).`
  return `${rule.min} members normally; a 5th member is allowed only if the single Third Year 5-member slot is still available.`
}

export function TeamRegisterPage() {
  const [step, setStep] = useState(0)
  const [teamName, setTeamName] = useState('')
  const [category, setCategory] = useState('Second Year')
  const [leader, setLeader] = useState(emptyPerson())
  const [members, setMembers] = useState([emptyPerson(), emptyPerson(), emptyPerson()])
  const [errors, setErrors] = useState([])
  const [submitting, setSubmitting] = useState(false)
  const [statusChecked, setStatusChecked] = useState(false)
  const [closed, setClosed] = useState(false)
  const [result, setResult] = useState(null)

  useEffect(() => {
    getRegistrationStatus()
      .then((s) => {
        if (!s.teamOpen) setClosed(true)
      })
      .catch(() => {})
      .finally(() => setStatusChecked(true))
  }, [])

  const total = 1 + members.length
  const rule = TEAM_SIZES[category]

  // Keep member rows in sync when category changes (default to minimum size).
  function handleCategoryChange(value) {
    setCategory(value)
    const r = TEAM_SIZES[value]
    if (!r) return
    setMembers((prev) => {
      if (prev.length < r.min - 1) {
        return [...prev, ...Array.from({ length: r.min - 1 - prev.length }, emptyPerson)]
      }
      if (prev.length > r.max - 1) {
        return prev.slice(0, r.max - 1)
      }
      return prev
    })
  }

  function canAdd() {
    return rule && total < rule.max
  }
  function canRemove() {
    return rule && total > rule.min
  }

  const allPeople = useMemo(() => [leader, ...members], [leader, members])

  function validateCurrentStep() {
    if (step === 0) {
      const e = []
      if (!teamName.trim()) e.push('Team name is required.')
      else if (teamName.trim().length > 120) e.push('Team name is too long (max 120).')
      if (!TEAM_CATEGORIES.includes(category)) e.push('Select a valid team category.')
      setErrors(e)
      return e.length === 0
    }
    if (step === 1) {
      const { errors: e } = validateTeamForm({
        teamName: teamName || 'x',
        category,
        leader,
        members: [],
      })
      // validateTeamForm with no members checks size; filter to leader-only errors.
      const leaderErrors = e.filter((m) => m.startsWith('Team Leader'))
      setErrors(leaderErrors)
      return leaderErrors.length === 0
    }
    if (step === 2) {
      const { errors: e } = validateTeamForm({ teamName: teamName || 'x', category, leader, members })
      // Exclude team-name noise (already validated) — keep member/size/dupe errors.
      const memberErrors = e.filter((m) => !m.startsWith('Team name'))
      setErrors(memberErrors)
      return memberErrors.length === 0
    }
    return true
  }

  function next() {
    if (validateCurrentStep()) {
      setErrors([])
      setStep((s) => Math.min(s + 1, 3))
    }
  }

  async function submit() {
    const { valid, errors: e } = validateTeamForm({ teamName, category, leader, members })
    if (!valid) {
      setErrors(e)
      return
    }
    setErrors([])
    setSubmitting(true)
    try {
      const data = await registerTeam({ teamName, category, leader, members })
      setResult(data)
      setStep(4)
    } catch (err) {
      setErrors([err.message])
    } finally {
      setSubmitting(false)
    }
  }

  if (!statusChecked) {
    return (
      <PageContainer narrow>
        <Loading label="Checking registration status…" />
      </PageContainer>
    )
  }

  if (closed) {
    return (
      <PageContainer narrow>
        <h1 className="text-2xl font-semibold">Team registration is closed</h1>
        <p className="mt-2 text-sm text-muted">
          Team registrations are currently closed. Please check back later.
        </p>
      </PageContainer>
    )
  }

  return (
    <PageContainer narrow>
      <h1 className="text-2xl font-semibold tracking-tight">Team Registration</h1>
      <div className="mt-4">
        <StepIndicator steps={STEPS} current={step} />
      </div>

      {errors.length > 0 && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4" role="alert">
          <ul className="list-disc space-y-1 pl-5 text-sm text-red-700">
            {errors.map((e) => (
              <li key={e}>{e}</li>
            ))}
          </ul>
        </div>
      )}

      {step === 0 && (
        <div className="mt-6 space-y-4">
          <Input
            label="Team Name"
            value={teamName}
            onChange={(e) => setTeamName(e.target.value)}
            placeholder="e.g. Null Pointers"
            maxLength={120}
            required
          />
          <Select label="Team Category" value={category} onChange={(e) => handleCategoryChange(e.target.value)}>
            {TEAM_CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </Select>
          <p className="text-xs text-muted">
            The category applies to the whole team. Every member is registered under this
            category — categories are never derived from USNs.
          </p>
          <div className="flex justify-end">
            <Button onClick={next}>Continue</Button>
          </div>
        </div>
      )}

      {step === 1 && (
        <div className="mt-6 space-y-4">
          <MemberCard index={0} isLeader member={leader} onChange={setLeader} />
          <div className="flex justify-between">
            <Button variant="secondary" onClick={() => setStep(0)}>
              Back
            </Button>
            <Button onClick={next}>Continue</Button>
          </div>
        </div>
      )}

      {step === 2 && (
        <div className="mt-6 space-y-4">
          <p className="text-sm text-muted">
            {expectedCount(category, members)} Total: {total} (including leader).
          </p>
          {members.map((m, i) => (
            <MemberCard
              key={i}
              index={i + 1}
              member={m}
              canRemove={canRemove()}
              onRemove={() => setMembers((prev) => prev.filter((_, j) => j !== i))}
              onChange={(updated) =>
                setMembers((prev) => prev.map((p, j) => (j === i ? updated : p)))
              }
            />
          ))}
          {canAdd() && (
            <Button
              variant="secondary"
              onClick={() => setMembers((prev) => [...prev, emptyPerson()])}
            >
              + Add member
            </Button>
          )}
          <div className="flex justify-between">
            <Button variant="secondary" onClick={() => setStep(1)}>
              Back
            </Button>
            <Button onClick={next}>Review</Button>
          </div>
        </div>
      )}

      {step === 3 && (
        <div className="mt-6 space-y-4">
          <dl className="rounded-xl border border-line p-4 text-sm">
            <div className="flex justify-between py-1">
              <dt className="text-muted">Team Name</dt>
              <dd className="font-medium">{teamName.trim()}</dd>
            </div>
            <div className="flex justify-between py-1">
              <dt className="text-muted">Category</dt>
              <dd className="font-medium">{category}</dd>
            </div>
            <div className="flex justify-between py-1">
              <dt className="text-muted">Total members</dt>
              <dd className="font-medium">{total}</dd>
            </div>
          </dl>
          <div className="space-y-2">
            {allPeople.map((p, i) => (
              <div key={i} className="rounded-xl border border-line p-3 text-sm">
                <p className="font-medium">
                  {i === 0 ? 'Team Leader' : `Member ${i + 1}`}: {p.name.trim()}
                </p>
                <p className="text-muted">
                  {normalizeUSN(p.usn)} · {String(p.phone).trim()}
                </p>
              </div>
            ))}
          </div>
          <div className="flex justify-between">
            <Button variant="secondary" onClick={() => setStep(2)} disabled={submitting}>
              Back
            </Button>
            <Button onClick={submit} disabled={submitting}>
              {submitting ? 'Submitting…' : 'Submit Registration'}
            </Button>
          </div>
        </div>
      )}

      {step === 4 && result && (
        <SuccessCard
          title="Registration Successful"
          idLabel="Team Registration ID"
          id={result.registration_id ?? result.registrationId ?? result.id}
        />
      )}
    </PageContainer>
  )
}

export function SuccessCard({ title, idLabel, id }) {
  const [copied, setCopied] = useState(false)
  async function copy() {
    try {
      await navigator.clipboard.writeText(String(id))
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      setCopied(false)
    }
  }
  return (
    <div className="mt-6 rounded-xl border border-line bg-surface p-6 text-center">
      <h2 className="text-xl font-semibold">{title}</h2>
      {id && (
        <>
          <p className="mt-2 text-xs uppercase tracking-widest text-muted">{idLabel}</p>
          <p className="mt-1 font-mono text-2xl font-semibold tracking-tight">{id}</p>
          <Button variant="secondary" className="mt-4" onClick={copy}>
            {copied ? 'Copied!' : 'Copy Registration ID'}
          </Button>
        </>
      )}
      <p className="mt-4 text-sm text-muted">
        Please save this ID — you will need it for all further communication.
      </p>
    </div>
  )
}

// Re-exported to keep USNInput import usage explicit for lint.
export { USNInput }
