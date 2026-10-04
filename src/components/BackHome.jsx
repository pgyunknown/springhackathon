import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Button, Modal } from './ui.jsx'

const linkClassName =
  'inline-block rounded py-1 text-sm text-muted transition-colors hover:text-ink focus:outline-none focus-visible:ring-2 focus-visible:ring-black'

/**
 * Consistent "Back to Home" control for public pages (never on `/` itself).
 * When `confirm` is true, leaving shows a lightweight confirmation dialog
 * (reusing the shared Modal) so entered form data is not silently lost.
 * Navigation always targets the home route via React Router.
 */
export function BackHome({ confirm = false }) {
  const navigate = useNavigate()
  const [showConfirm, setShowConfirm] = useState(false)

  if (!confirm) {
    return (
      <Link to="/" aria-label="Back to home" className={linkClassName}>
        ← Back to Home
      </Link>
    )
  }

  return (
    <>
      <Link
        to="/"
        aria-label="Back to home"
        className={linkClassName}
        onClick={(e) => {
          e.preventDefault()
          setShowConfirm(true)
        }}
      >
        ← Back to Home
      </Link>
      <Modal
        open={showConfirm}
        onClose={() => setShowConfirm(false)}
        title="Leave without submitting?"
      >
        <p className="text-sm text-muted">
          The information you entered on this page will be lost.
        </p>
        <div className="mt-4 flex justify-end gap-2">
          <Button variant="secondary" onClick={() => setShowConfirm(false)}>
            Stay
          </Button>
          <Button onClick={() => navigate('/')}>Leave</Button>
        </div>
      </Modal>
    </>
  )
}
