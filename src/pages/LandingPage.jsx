import { useState } from 'react'
import { Link } from 'react-router-dom'
import { PageContainer } from '../components/ui.jsx'

const RULE_GROUPS = [
  {
    id: 'team-registration',
    title: 'Registration Rules',
    rules: [
      {
        title: '1. Team Size',
        items: [
          '2nd-year teams: Exactly 4 members.',
          '3rd-year teams: Exactly 4 members.',
          'Only one 5-member slot is available for a 3rd-year team.(First come first serve)',
          'Once the 5-member slot is claimed by the first complete eligible team, no other 5-member 3rd-year team can register.',
        ],
      },
      {
        title: '2. Same-Year Teams Only',
        items: [
          'Teams must consist entirely of students from the same year.',
          '3rd-year students cannot form a team with 2nd-year students and vise versa.',
        ],
      },
      {
        title: '3. Mentor Registration',
        items: [
          'Only 7th-semester students are eligible to register as mentors for the hackathon.',
          'Mentors must provide a valid USN registered in the official student database. USN details will be verified during registration.',
        ],
      },
    ],
  },
  {
    id: 'hackathon',
    title: 'Hackathon Rules',
    rules: [
      {
        title: '1. Code of Conduct',
        items: [
          "All participants must follow the college's code of conduct and maintain appropriate discipline throughout the hackathon. Any violation may result in disqualification.",
        ],
      },
      {
        title: '2. Use of AI Tools',
        items: [
          'AI tools and other development-assistance tools are permitted.',
          'However, every participant must understand the work they submit and be able to explain their implementation during evaluation.',
        ],
      },
      {
        title: '3. Originality of the Prototype',
        items: [
          'The prototype must be developed during the hackathon.',
          'Previously developed projects, substantial pre-built solutions, or templates that form the core of the submission are not permitted.',
          'Standard frameworks, libraries, APIs, and development tools are permitted.',
          'Violation of the originality requirement may result in disqualification.',
        ],
      },
      {
        title: '4. GitHub Submission',
        items: [
          "All functional prototypes must be pushed to the team's designated GitHub repository before the submission deadline.",
          'Exception: Figma designs and UI/UX-only submissions do not require a GitHub submission.',
        ],
      },
      {
        title: '5. Mentor & Guide Authority',
        items: [
          'Mentors/Guides may disqualify a team or participant in cases involving violation of hackathon rules, misconduct, or any situation that compromises the integrity of the event.',
        ],
      },
      {
        title: '6. Personal Equipment',
        items: [
          'Participants are responsible for bringing their own required accessories and equipment, including chargers, adapters, extension cords, peripherals, and other required equipment.',
          'These will not be provided by the organizers.',
        ],
      },
      {
        title: '7. Wi-Fi',
        items: [
          'Wi-Fi will be provided.',
          'Participants may bring their own snacks if required.',
          'Online ordering or delivery of food or other items is not permitted during the hackathon.',
        ],
      },
      {
        title: '8. Mentor Participation',
        items: [
          'Each team may have a mentor/guide associated with their team, where applicable.',
          'Mentors/Guides may provide guidance and technical suggestions during the hackathon.',
          'Mentors/Guides are expected to support teams without taking over the development or implementation of the solution.',
          'Participants remain responsible for their own ideas, implementation, and final submission.',
          'Mentors/Guides may disqualify a team or participant for rule violations, misconduct, or circumstances that compromise the integrity of the event.',
        ],
      },
    ],
  },
]

function RuleGroup({ group, open, onToggle }) {
  const panelId = `rules-panel-${group.id}`
  const buttonId = `rules-button-${group.id}`
  return (
    <div className="border-b border-line last:border-b-0">
      <h3>
        <button
          type="button"
          id={buttonId}
          aria-expanded={open}
          aria-controls={panelId}
          onClick={onToggle}
          className="flex w-full items-center justify-between gap-4 px-4 py-4 text-left text-sm font-semibold text-ink transition-colors hover:bg-surface focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-black sm:px-5 sm:text-base"
        >
          {group.title}
          <svg
            aria-hidden="true"
            className={`h-4 w-4 shrink-0 text-muted transition-transform ${open ? 'rotate-180' : ''}`}
            viewBox="0 0 16 16"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
          >
            <path d="M4 6l4 4 4-4" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
      </h3>
      {open && (
        <div
          id={panelId}
          role="region"
          aria-labelledby={buttonId}
          className="px-4 pb-5 sm:px-5"
        >
          {group.rules.map((rule) => (
            <div key={rule.title} className="mt-4 first:mt-0">
              <h4 className="text-sm font-semibold text-ink">{rule.title}</h4>
              <ul className="mt-2 list-disc space-y-1.5 pl-5 text-sm leading-relaxed text-muted">
                {rule.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export function LandingPage() {
  const [openGroups, setOpenGroups] = useState([])

  function toggleGroup(id) {
    setOpenGroups((prev) =>
      prev.includes(id) ? prev.filter((g) => g !== id) : [...prev, id],
    )
  }

  return (
    <PageContainer narrow>
      <section className="py-10 text-center sm:py-16">
        <h1 className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">
          Spring Hackathon 1.0
        </h1>
        <p className="mx-auto mt-4 max-w-xl text-base text-muted">
          An Intra-Branch Hackathon.
        </p>
        <div className="mt-10 grid gap-3 sm:grid-cols-2">
          <Link
            to="/register/team"
            className="rounded-xl bg-black px-6 py-5 text-left text-white transition-colors hover:bg-neutral-800"
          >
            <span className="block text-base font-semibold">Register Team</span>
            <span className="mt-1 block text-sm text-neutral-300">
              Team Registration 
            </span>
          </Link>
          <Link
            to="/register/mentor"
            className="rounded-xl border border-line bg-white px-6 py-5 text-left transition-colors hover:bg-surface"
          >
            <span className="block text-base font-semibold">Mentor Registration</span>
            <span className="mt-1 block text-sm text-muted">Sign up as a mentor</span>
          </Link>
        </div>
      </section>
      <section aria-labelledby="rules-heading" className="mt-4 border-t border-line pb-10 pt-10">
        <h2
          id="rules-heading"
          className="text-center text-2xl font-semibold tracking-tight"
        >
          Rules And Regulations
        </h2>
        <div className="mt-6 overflow-hidden rounded-xl border border-line bg-white">
          {RULE_GROUPS.map((group) => (
            <RuleGroup
              key={group.id}
              group={group}
              open={openGroups.includes(group.id)}
              onToggle={() => toggleGroup(group.id)}
            />
          ))}
        </div>
      </section>
      <footer className="mt-4 border-t border-line py-8 text-center">
        <p className="text-sm font-semibold text-ink">Spring Hackathon 1.0</p>
        <p className="mt-1 text-xs text-muted">Computer Science & Business Systems</p>
        <p className="mt-1 text-xs text-muted">© 2026</p>
      </footer>
    </PageContainer>
  )
}
