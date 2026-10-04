import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Navbar } from './components/Navbar.jsx'
import { LandingPage } from './pages/LandingPage.jsx'
import { MentorRegisterPage } from './pages/MentorRegisterPage.jsx'
import { TeamRegisterPage } from './pages/TeamRegisterPage.jsx'

export default function App() {
  return (
    <BrowserRouter>
      <Navbar />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/register/team" element={<TeamRegisterPage />} />
        <Route path="/register/mentor" element={<MentorRegisterPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
