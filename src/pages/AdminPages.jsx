import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Input, Loading, PageContainer } from '../components/ui.jsx'
import { fetchMentorList, fetchTeamDetail, fetchTeamList } from '../services/adminService.js'

export function AdminTeamsPage() {
  const [search, setSearch] = useState('')
  const [teams, setTeams] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const t = setTimeout(() => {
      setLoading(true)
      fetchTeamList({ search })
        .then(setTeams)
        .catch((e) => setError(e.message))
        .finally(() => setLoading(false))
    }, 250)
    return () => clearTimeout(t)
  }, [search])

  return (
    <PageContainer>
      <h1 className="text-2xl font-semibold tracking-tight">Teams</h1>
      <div className="mt-4 max-w-sm">
        <Input
          label="Search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Team name or registration ID"
        />
      </div>
      {error && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">
          {error}
        </div>
      )}
      {loading ? (
        <Loading label="Loading teams…" />
      ) : teams.length === 0 ? (
        <p className="mt-6 text-sm text-muted">No teams found.</p>
      ) : (
        <ul className="mt-4 divide-y divide-line rounded-xl border border-line">
          {teams.map((t) => (
            <li key={t.id}>
              <Link to={`/admin/teams/${t.id}`} className="block px-4 py-3 hover:bg-surface">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium">{t.team_name}</p>
                    <p className="text-xs text-muted">
                      {t.category} · {t.member_count} members
                    </p>
                  </div>
                  <span className="font-mono text-xs text-muted">{t.registration_id}</span>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </PageContainer>
  )
}

export function AdminTeamDetailInner({ id }) {
  const [detail, setDetail] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    fetchTeamDetail(id)
      .then(setDetail)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [id])

  if (loading) {
    return (
      <PageContainer>
        <Loading label="Loading team…" />
      </PageContainer>
    )
  }

  if (error || !detail) {
    return (
      <PageContainer>
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">
          {error || 'Team not found.'}
        </div>
        <Link to="/admin/teams" className="mt-4 inline-block text-sm underline">
          Back to teams
        </Link>
      </PageContainer>
    )
  }

  const { team, members } = detail
  return (
    <PageContainer narrow>
      <Link to="/admin/teams" className="text-sm text-muted hover:text-ink">
        ← Back to teams
      </Link>
      <h1 className="mt-2 text-2xl font-semibold tracking-tight">{team.team_name}</h1>
      <p className="mt-1 font-mono text-sm text-muted">{team.registration_id}</p>
      <p className="mt-1 text-sm text-muted">
        {team.category} · {team.member_count} members
      </p>
      <h2 className="mt-6 text-sm font-semibold">Members</h2>
      <ul className="mt-2 space-y-2">
        {members.map((m) => (
          <li key={m.id} className="rounded-xl border border-line p-3 text-sm">
            <p className="font-medium">
              {m.name}{' '}
              {m.is_leader && (
                <span className="ml-1 rounded-full bg-black px-2 py-0.5 text-[11px] text-white">
                  LEADER
                </span>
              )}
            </p>
            <p className="text-muted">
              {m.usn} · {m.phone}
            </p>
          </li>
        ))}
      </ul>
    </PageContainer>
  )
}

export function AdminMentorsPage() {
  const [search, setSearch] = useState('')
  const [mentors, setMentors] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const t = setTimeout(() => {
      setLoading(true)
      fetchMentorList({ search })
        .then(setMentors)
        .catch((e) => setError(e.message))
        .finally(() => setLoading(false))
    }, 250)
    return () => clearTimeout(t)
  }, [search])

  return (
    <PageContainer>
      <h1 className="text-2xl font-semibold tracking-tight">Mentors</h1>
      <div className="mt-4 max-w-sm">
        <Input
          label="Search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Name, email or registration ID"
        />
      </div>
      {error && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">
          {error}
        </div>
      )}
      {loading ? (
        <Loading label="Loading mentors…" />
      ) : mentors.length === 0 ? (
        <p className="mt-6 text-sm text-muted">No mentors found.</p>
      ) : (
        <ul className="mt-4 divide-y divide-line rounded-xl border border-line">
          {mentors.map((m) => (
            <li key={m.id} className="px-4 py-3">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <p className="text-sm font-medium">{m.name}</p>
                  <p className="text-xs text-muted">
                    {m.email} · {m.phone}
                    {m.department ? ` · ${m.department}` : ''}
                  </p>
                </div>
                <span className="font-mono text-xs text-muted">{m.registration_id}</span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </PageContainer>
  )
}
