import { Link } from 'react-router-dom'
import { PageContainer } from '../components/ui.jsx'

export function LandingPage() {
  return (
    <PageContainer narrow>
      <section className="py-10 text-center sm:py-16">
        <p className="text-xs font-medium uppercase tracking-widest text-muted">
          Malnad College of Engineering
        </p>
        <h1 className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">
          Spring Hackathon
        </h1>
        <p className="mx-auto mt-4 max-w-xl text-base text-muted">
          Branch-level hackathon registration for teams and mentors.
        </p>
        <div className="mt-10 grid gap-3 sm:grid-cols-3">
          <Link
            to="/register/team"
            className="rounded-xl bg-black px-6 py-5 text-left text-white transition-colors hover:bg-neutral-800"
          >
            <span className="block text-base font-semibold">Register Team</span>
            <span className="mt-1 block text-sm text-neutral-300">
              Register your 4-member team
            </span>
          </Link>
          <Link
            to="/register/mentor"
            className="rounded-xl border border-line bg-white px-6 py-5 text-left transition-colors hover:bg-surface"
          >
            <span className="block text-base font-semibold">Mentor Registration</span>
            <span className="mt-1 block text-sm text-muted">Sign up as a mentor</span>
          </Link>
          <Link
            to="/admin/login"
            className="rounded-xl border border-line bg-white px-6 py-5 text-left transition-colors hover:bg-surface"
          >
            <span className="block text-base font-semibold">Admin Access</span>
            <span className="mt-1 block text-sm text-muted">Manage registrations</span>
          </Link>
        </div>
      </section>
    </PageContainer>
  )
}
