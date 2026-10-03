import { useEffect, useState } from 'react'
import { Button, Loading, PageContainer } from '../components/ui.jsx'
import { getSettings, setSettings } from '../services/adminService.js'

export function AdminSettingsPage() {
  const [settings, setSettingsState] = useState({ teamOpen: true, mentorOpen: true })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    getSettings()
      .then(setSettingsState)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  async function save(next) {
    setSaving(true)
    setError('')
    setSaved(false)
    try {
      await setSettings(next)
      setSettingsState(next)
      setSaved(true)
    } catch (e) {
      setError(e.message)
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <PageContainer narrow>
        <Loading label="Loading settings…" />
      </PageContainer>
    )
  }

  return (
    <PageContainer narrow>
      <h1 className="text-2xl font-semibold tracking-tight">Registration Settings</h1>
      {error && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">
          {error}
        </div>
      )}
      {saved && (
        <div className="mt-4 rounded-xl border border-green-200 bg-green-50 p-4 text-sm text-green-700" role="status">
          Settings saved.
        </div>
      )}
      <div className="mt-6 space-y-3">
        <ToggleRow
          label="Team registration"
          open={settings.teamOpen}
          disabled={saving}
          onChange={(v) => save({ ...settings, teamOpen: v })}
        />
        <ToggleRow
          label="Mentor registration"
          open={settings.mentorOpen}
          disabled={saving}
          onChange={(v) => save({ ...settings, mentorOpen: v })}
        />
      </div>
    </PageContainer>
  )
}

function ToggleRow({ label, open, onChange, disabled }) {
  return (
    <div className="flex items-center justify-between rounded-xl border border-line p-4">
      <div>
        <p className="text-sm font-medium">{label}</p>
        <p className="text-xs text-muted">{open ? 'Open' : 'Closed'}</p>
      </div>
      <Button
        variant="secondary"
        disabled={disabled}
        onClick={() => onChange(!open)}
        aria-pressed={open}
      >
        {open ? 'Close' : 'Open'}
      </Button>
    </div>
  )
}
