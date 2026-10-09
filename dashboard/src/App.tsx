import { useEffect } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { setUnauthorizedHandler } from './api/client';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { Layout } from './components/Layout';
import { BlocklistPage } from './pages/BlocklistPage';
import { AuditPage } from './pages/AuditPage';
import { CasesPage } from './pages/CasesPage';
import { CloudPage } from './pages/CloudPage';
import { ForensicPage } from './pages/ForensicPage';
import { InternationalPage } from './pages/InternationalPage';
import { LegalPage } from './pages/LegalPage';
import { Login } from './pages/Login';
import { OverviewPage } from './pages/Overview';
import { PatternsPage } from './pages/Patterns';
import { ReportDetailPage } from './pages/ReportDetail';
import { ReportsPage } from './pages/Reports';
import { UsersPage } from './pages/UsersPage';
import { VictimAlertsPage } from './pages/VictimAlertsPage';

function RequireAuth({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function ApiSessionBridge() {
  const { logout } = useAuth();
  useEffect(() => {
    setUnauthorizedHandler(logout);
    return () => setUnauthorizedHandler(null);
  }, [logout]);
  return null;
}

export default function App() {
  return (
    <AuthProvider>
      <ApiSessionBridge />
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <RequireAuth>
                <Layout />
              </RequireAuth>
            }
          >
            <Route index element={<OverviewPage />} />
            <Route path="reports" element={<ReportsPage />} />
            <Route path="reports/:id" element={<ReportDetailPage />} />
            <Route path="cases" element={<CasesPage />} />
            <Route path="patterns" element={<PatternsPage />} />
            <Route path="forensic" element={<ForensicPage />} />
            <Route path="legal" element={<LegalPage />} />
            <Route path="cloud" element={<CloudPage />} />
            <Route path="blocklist" element={<BlocklistPage />} />
            <Route path="alerts" element={<VictimAlertsPage />} />
            <Route path="international" element={<InternationalPage />} />
            <Route path="users" element={<UsersPage />} />
            <Route path="audit" element={<AuditPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
