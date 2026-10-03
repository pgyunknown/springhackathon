import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

let supabase = null

if (url && anonKey) {
  supabase = createClient(url, anonKey)
} else if (import.meta.env.DEV) {
  globalThis.console?.warn(
    'Supabase env vars missing (VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY). Backend calls will fail until configured.',
  )
}

export function getSupabase() {
  if (!supabase) {
    throw new Error(
      'Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.',
    )
  }
  return supabase
}

export { supabase }
