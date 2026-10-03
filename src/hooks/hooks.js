import { useCallback, useEffect, useState } from 'react'
import { getSupabase } from '../lib/supabase.js'

export function useAdminSession() {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let mounted = true
    async function init() {
      try {
        const sb = getSupabase()
        const { data } = await sb.auth.getSession()
        if (mounted) setSession(data.session ?? null)
        const { data: sub } = sb.auth.onAuthStateChange((_e, s) => setSession(s))
        if (mounted) setLoading(false)
        return () => sub.subscription.unsubscribe()
      } catch {
        if (mounted) setLoading(false)
      }
    }
    const cleanupPromise = init()
    return () => {
      mounted = false
      cleanupPromise?.then?.((fn) => typeof fn === 'function' && fn())
    }
  }, [])

  const signOut = useCallback(async () => {
    const sb = getSupabase()
    await sb.auth.signOut()
  }, [])

  return { session, loading, signOut }
}

export function useRegistrationStatus() {
  const [status, setStatus] = useState({ teamOpen: true, mentorOpen: true })
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let mounted = true
    async function load() {
      try {
        const sb = getSupabase()
        const { data, error: err } = await sb.rpc('get_registration_status')
        if (err) throw err
        if (!mounted) return
        if (typeof data === 'boolean') setStatus({ teamOpen: data, mentorOpen: data })
        else
          setStatus({
            teamOpen: data?.team_open ?? true,
            mentorOpen: data?.mentor_open ?? true,
          })
      } catch (e) {
        if (mounted) setError(e.message)
      } finally {
        if (mounted) setLoading(false)
      }
    }
    load()
    return () => {
      mounted = false
    }
  }, [])

  return { status, loading, error }
}
