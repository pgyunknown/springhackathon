export function Button({ variant = 'primary', className = '', ...props }) {
  const base =
    'inline-flex items-center justify-center rounded-lg2 px-5 py-2.5 text-sm font-medium transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-black disabled:opacity-50 disabled:cursor-not-allowed'
  const styles = {
    primary: 'bg-black text-white hover:bg-neutral-800',
    secondary: 'border border-line bg-white text-ink hover:bg-surface',
    danger: 'bg-red-600 text-white hover:bg-red-700',
  }
  return <button className={`${base} ${styles[variant]} ${className}`} {...props} />
}

export function Input({ label, error, className = '', ...props }) {
  return (
    <label className="block">
      {label && <span className="mb-1 block text-sm font-medium text-ink">{label}</span>}
      <input
        className={`w-full rounded-lg2 border px-3 py-2 text-sm outline-none focus:border-black ${error ? 'border-red-500' : 'border-line'} ${className}`}
        {...props}
      />
      {error && <span className="mt-1 block text-xs text-red-600">{error}</span>}
    </label>
  )
}

export function Select({ label, error, children, className = '', ...props }) {
  return (
    <label className="block">
      {label && <span className="mb-1 block text-sm font-medium text-ink">{label}</span>}
      <select
        className={`w-full rounded-lg2 border bg-white px-3 py-2 text-sm outline-none focus:border-black ${error ? 'border-red-500' : 'border-line'} ${className}`}
        {...props}
      >
        {children}
      </select>
      {error && <span className="mt-1 block text-xs text-red-600">{error}</span>}
    </label>
  )
}

export function Modal({ open, onClose, title, children }) {
  if (!open) return null
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={onClose}
    >
      <div
        className="w-full max-w-md rounded-xl bg-white p-6 shadow-lg"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-lg font-semibold">{title}</h2>
        <div className="mt-4">{children}</div>
      </div>
    </div>
  )
}

export function Loading({ label = 'Loading…' }) {
  return (
    <div className="flex items-center justify-center py-10" role="status" aria-label={label}>
      <div className="h-6 w-6 animate-spin rounded-full border-2 border-line border-t-black" />
      <span className="ml-3 text-sm text-muted">{label}</span>
    </div>
  )
}

export function StepIndicator({ steps, current }) {
  return (
    <ol className="flex flex-wrap items-center gap-2" aria-label="Registration progress">
      {steps.map((s, i) => {
        const done = i < current
        const active = i === current
        return (
          <li key={s} className="flex items-center gap-2">
            <span
              aria-current={active ? 'step' : undefined}
              className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-semibold ${
                done ? 'bg-black text-white' : active ? 'border-2 border-black text-ink' : 'border border-line text-muted'
              }`}
            >
              {done ? '✓' : i + 1}
            </span>
            <span className={`text-xs ${active ? 'font-semibold text-ink' : 'text-muted'}`}>{s}</span>
            {i < steps.length - 1 && <span className="mx-1 h-px w-6 bg-line" aria-hidden="true" />}
          </li>
        )
      })}
    </ol>
  )
}

export function PageContainer({ children, narrow = false }) {
  return (
    <main className={`mx-auto w-full px-4 py-10 sm:px-6 ${narrow ? 'max-w-2xl' : 'max-w-5xl'}`}>
      {children}
    </main>
  )
}

/**
 * USN input: plain text field with trim + uppercase normalization.
 * Intentionally performs NO validity lookup, NO database query,
 * NO year/semester derivation, NO valid/invalid messaging.
 */
export function USNInput({ label = 'USN', value, onChange, error, ...props }) {
  return (
    <Input
      label={label}
      value={value}
      error={error}
      autoComplete="off"
      spellCheck={false}
      onChange={(e) => onChange(e.target.value.toUpperCase())}
      onBlur={(e) => onChange(e.target.value.trim().toUpperCase())}
      {...props}
    />
  )
}

export function MemberCard({ index, isLeader, member, onChange, onRemove, canRemove }) {
  const set = (field) => (e) => onChange({ ...member, [field]: e.target.value })
  return (
    <div className="rounded-xl border border-line bg-white p-4">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-sm font-semibold">
          {isLeader ? 'Team Leader' : `Member ${index + 1}`}
          {isLeader && (
            <span className="ml-2 rounded-full bg-black px-2 py-0.5 text-[11px] font-medium text-white">
              LEADER
            </span>
          )}
        </h3>
        {canRemove && !isLeader && (
          <button
            type="button"
            onClick={onRemove}
            className="text-xs text-red-600 hover:underline"
            aria-label={`Remove member ${index + 1}`}
          >
            Remove
          </button>
        )}
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <Input label="Name" value={member.name} onChange={set('name')} placeholder="Full name" required />
        <USNInput label="USN" value={member.usn} onChange={(v) => onChange({ ...member, usn: v })} placeholder="e.g. 4MC22CB001" required />
        <Input label="Phone" value={member.phone} onChange={set('phone')} placeholder="+91 …" inputMode="tel" required />
      </div>
    </div>
  )
}
