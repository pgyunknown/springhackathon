import { useEffect, useState } from 'react'
import { Button, Input, Loading, PageContainer, USNInput } from '../components/ui.jsx'
import { SuccessCard } from './TeamRegisterPage.jsx'
import { getRegistrationStatus, registerMentor } from '../services/publicService.js'

const empty = () => ({ name: '', email: '', phone: '', department: '', usn: '' })

export function MentorRegisterPage() {
  const [form, setForm] = useState(empty())
  const [errors, setErrors] = useState([])
  const [submitting, setSubmitting] = useState(false)
  const [statusChecked, setStatusChecked] = useState(false)
  const [closed, setClosed] = useState(false)
  const [result, setResult] = useState(null)

  useEffect(() => {
    getRegistrationStatus()
      .then((s) => {
        if (!s.mentorOpen) setClosed(true)
      })
      .catch(() => {})
      .finally(() => setStatusChecked(true))
  }, [])

  const set = (field) => (e) => setForm((f) => ({ ...f, [field]: e.target.value }))

  function validate() {
    const e = []
    if (!form.name.trim()) e.push('Name is required.')
    else if (form.name.trim().length > 100) e.push('Name is too long (max 100).')
    if (!form.email.trim()) e.push('Email is required.')
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim()))
      e.push('Email format looks invalid.')
    if (!form.phone.trim()) e.push('Phone is required.')
    if (form.usn && String(form.usn).trim().length > 20) e.push('USN is too long (max 20).')
    if (form.department && form.department.trim().length > 120)
      e.push('Department is too long (max 120).')
    return e
  }

  async function submit(ev) {
    ev.preventDefault()
    const e = validate()
    if (e.length > 0) {
      setErrors(e)
      return
    }
    setErrors([])
    setSubmitting(true)
    try {
      const data = await registerMentor({
        ...form,
        usn: form.usn ? String(form.usn).trim().toUpperCase() : null,
      })
      setResult(data)
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
        <h1 className="text-2xl font-semibold">Mentor registration is closed</h1>
        <p className="mt-2 text-sm text-muted">
          Mentor registrations are currently closed. Please check back later.
        </p>
      </PageContainer>
    )
  }

  if (result) {
    return (
      <PageContainer narrow>
        <SuccessCard
          title="Registration Successful"
          idLabel="Mentor Registration ID"
          id={result.registration_id ?? result.registrationId ?? result.id}
        />
      </PageContainer>
    )
  }

  return (
    <PageContainer narrow>
      <h1 className="text-2xl font-semibold tracking-tight">Mentor Registration</h1>
      <p className="mt-2 text-sm text-muted">
        USN is optional registration data only — it is never validated.
      </p>

      {errors.length > 0 && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4" role="alert">
          <ul className="list-disc space-y-1 pl-5 text-sm text-red-700">
            {errors.map((e) => (
              <li key={e}>{e}</li>
            ))}
          </ul>
        </div>
      )}

      <form onSubmit={submit} className="mt-6 space-y-4">
        <Input label="Full Name" value={form.name} onChange={set('name')} required maxLength={100} />
        <Input label="Email" type="email" value={form.email} onChange={set('email')} required />
        <Input label="Phone" value={form.phone} onChange={set('phone')} inputMode="tel" required />
        <Input
          label="Department (optional)"
          value={form.department}
          onChange={set('department')}
          placeholder="e.g. Computer Science"
        />
        <USNInput
          label="USN (optional)"
          value={form.usn}
          onChange={(v) => setForm((f) => ({ ...f, usn: v }))}
          placeholder="If applicable"
        />
        <Button type="submit" disabled={submitting} className="w-full sm:w-auto">
          {submitting ? 'Submitting…' : 'Submit Registration'}
        </Button>
      </form>
    </PageContainer>
  )
}
