import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAdminSession } from '../hooks/hooks.js'
import { getSupabase } from '../lib/supabase.js'
import { Button } from './ui.jsx'

export function Navbar() {
  const { session, signOut } = useAdminSessionSafe()
  const navigate = useNavigate()

  async function handleSignOut() {
    await signOut()
    navigate('/admin/login')
  }

  return (
    <header className="border-b border-line bg-white">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3 sm:px-6">
        <Link to="/" className="text-sm font-semibold tracking-tight">
          Spring Hackathon 
        </Link>
        <nav className="flex items-center gap-4 text-sm">
          <Link to="/register/team" className="text-muted hover:text-ink">
            Register Team
          </Link>
          <Link to="/register/mentor" className="text-muted hover:text-ink">
            Mentor Registration
          </Link>
          {session ? (
            <>
              <Link to="/admin/dashboard" className="text-muted hover:text-ink">
                Dashboard
              </Link>
              <Button variant="secondary" className="px-3 py-1.5 text-xs" onClick={handleSignOut}>
                Sign out
              </Button>
            </>
          ) : (
            <Link to="/admin/login" className="text-muted hover:text-ink">
              Admin Login
            </Link>
          )}
        </nav>
      </div>
    </header>
  )
}

// Navbar is rendered outside auth context on public pages; guard against
// missing Supabase config so the public site still renders.
function useAdminSessionSafe() {
  const [session, setSession] = useState(null)
  useEffect(() => {
    let mounted = true
    try {
      const sb = getSupabase()
      sb.auth.getSession().then(({ data }) => {
        if (mounted) setSession(data.session ?? null)
      })
      const { data: sub } = sb.auth.onAuthStateChange((_e, s) => {
        if (mounted) setSession(s)
      })
      return () => {
        mounted = false
        sub.subscription.unsubscribe()
      }
    } catch {
      return () => {
        mounted = false
      }
    }
  }, [])
  async function signOut() {
    try {
      await getSupabase().auth.signOut()
    } catch {
      /* not configured */
    }
  }
  return { session, signOut }
}

export function RequireAdmin({ children }) {
  const { session, loading } = useAdminSession()
  const navigate = useNavigate()
  useEffect(() => {
    if (!loading && !session) navigate('/admin/login', { replace: true })
  }, [loading, session, navigate])
  if (loading) return <p className="px-4 py-10 text-sm text-muted">Checking session…</p>
  if (!session) return null
  return children
}
