import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Loading, PageContainer } from '../components/ui.jsx'
import { fetchCounts, getSettings } from '../services/adminService.js'

export function AdminDashboardPage() {
  const [counts, setCounts] = useState(null)
  const [settings, setSettings] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let mounted = true
    Promise.all([fetchCounts(), getSettings()])
      .then(([c, s]) => {
        if (mounted) {
          setCounts(c)
          setSettings(s)
        }
      })
      .catch((e) => {
        if (mounted) setError(e.message)
      })
      .finally(() => {
        if (mounted) setLoading(false)
      })
    return () => {
      mounted = false
    }
  }, [])

  if (loading) {
    return (
      <PageContainer>
        <Loading label="Loading dashboard…" />
      </PageContainer>
    )
  }

  return (
    <PageContainer>
      <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
      {error && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">
          {error}
        </div>
      )}
      {counts && (
        <div className="mt-6 grid gap-3 sm:grid-cols-3">
          <Stat label="Team registrations" value={counts.teamCount} to="/admin/teams" />
          <Stat label="Mentor registrations" value={counts.mentorCount} to="/admin/mentors" />
          <div className="rounded-xl border border-line p-5">
            <p className="text-xs uppercase tracking-widest text-muted">Registration status</p>
            <p className="mt-2 text-sm">
              Teams: <Status open={settings?.teamOpen} /> · Mentors:{' '}
              <Status open={settings?.mentorOpen} />
            </p>
            <Link to="/admin/settings" className="mt-2 inline-block text-sm underline">
              Manage settings
            </Link>
          </div>
        </div>
      )}
      {counts && (
        <div className="mt-6 rounded-xl border border-line p-5">
          <h2 className="text-sm font-semibold">Teams by category</h2>
          <ul className="mt-2 space-y-1 text-sm text-muted">
            {['Second Year', 'Third Year'].map((c) => (
              <li key={c} className="flex justify-between">
                <span>{c}</span>
                <span className="font-medium text-ink">{counts.byCategory[c] ?? 0}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </PageContainer>
  )
}

function Stat({ label, value, to }) {
  return (
    <Link to={to} className="rounded-xl border border-line p-5 transition-colors hover:bg-surface">
      <p className="text-xs uppercase tracking-widest text-muted">{label}</p>
      <p className="mt-2 text-3xl font-semibold tracking-tight">{value}</p>
    </Link>
  )
}

function Status({ open }) {
  return open ? (
    <span className="font-medium text-green-700">Open</span>
  ) : (
    <span className="font-medium text-red-700">Closed</span>
  )
}
