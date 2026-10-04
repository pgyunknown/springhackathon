import { Link } from 'react-router-dom'

export function Navbar() {
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
        </nav>
      </div>
    </header>
  )
}
