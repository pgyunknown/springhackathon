import { BrowserRouter, Navigate, Route, Routes, useParams } from 'react-router-dom'
import { Navbar, RequireAdmin } from './components/Navbar.jsx'
import { AdminLoginPage } from './pages/AdminLoginPage.jsx'
import { AdminDashboardPage } from './pages/AdminDashboardPage.jsx'
import { AdminMentorsPage, AdminTeamDetailInner, AdminTeamsPage } from './pages/AdminPages.jsx'
import { AdminSettingsPage } from './pages/AdminSettingsPage.jsx'
import { LandingPage } from './pages/LandingPage.jsx'
import { MentorRegisterPage } from './pages/MentorRegisterPage.jsx'
import { TeamRegisterPage } from './pages/TeamRegisterPage.jsx'

function TeamDetailRoute() {
  const { id } = useParams()
  return <AdminTeamDetailInner id={id} />
}

export default function App() {
  return (
    <BrowserRouter>
      <Navbar />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/register/team" element={<TeamRegisterPage />} />
        <Route path="/register/mentor" element={<MentorRegisterPage />} />
        <Route path="/admin/login" element={<AdminLoginPage />} />
        <Route
          path="/admin/dashboard"
          element={
            <RequireAdmin>
              <AdminDashboardPage />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/teams"
          element={
            <RequireAdmin>
              <AdminTeamsPage />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/teams/:id"
          element={
            <RequireAdmin>
              <TeamDetailRoute />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/mentors"
          element={
            <RequireAdmin>
              <AdminMentorsPage />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/settings"
          element={
            <RequireAdmin>
              <AdminSettingsPage />
            </RequireAdmin>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
