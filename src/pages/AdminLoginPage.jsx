import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Button, Input, PageContainer } from '../components/ui.jsx'
import { getSupabase } from '../lib/supabase.js'

export function AdminLoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  async function submit(ev) {
    ev.preventDefault()
    setError('')
    setLoading(true)
    try {
      const sb = getSupabase()
      const { error: err } = await sb.auth.signInWithPassword({
        email: email.trim(),
        password,
      })
      if (err) throw err
      navigate('/admin/dashboard', { replace: true })
    } catch (e) {
      setError(e.message || 'Sign-in failed.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <PageContainer narrow>
      <h1 className="text-2xl font-semibold tracking-tight">Admin Login</h1>
      <p className="mt-2 text-sm text-muted">Sign in with your administrator account.</p>
      {error && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" role="alert">
          {error}
        </div>
      )}
      <form onSubmit={submit} className="mt-6 space-y-4">
        <Input label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="username" />
        <Input label="Password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" />
        <Button type="submit" disabled={loading} className="w-full sm:w-auto">
          {loading ? 'Signing in…' : 'Sign in'}
        </Button>
      </form>
    </PageContainer>
  )
}
