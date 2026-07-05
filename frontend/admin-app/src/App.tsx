import { lazy, Suspense } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AdminAuthProvider } from "./context/AdminAuthContext";
import { RequireSuperAdmin } from "./components/RequireSuperAdmin";
import { AdminLayout, LoginPage } from "./pages/AdminLayout";
import { ForbiddenPage } from "./pages/ForbiddenPage";

const DashboardPage = lazy(() => import("./pages/DashboardPage").then((m) => ({ default: m.DashboardPage })));
const FleetPage = lazy(() => import("./pages/FleetPage").then((m) => ({ default: m.FleetPage })));
const LedgerPage = lazy(() => import("./pages/LedgerPage").then((m) => ({ default: m.LedgerPage })));
const PassportPage = lazy(() => import("./pages/PassportPage").then((m) => ({ default: m.PassportPage })));
const CaseMemoryPage = lazy(() => import("./pages/CaseMemoryPage").then((m) => ({ default: m.CaseMemoryPage })));
const ResearchIngestionPage = lazy(() =>
  import("./pages/ResearchIngestionPage").then((m) => ({ default: m.ResearchIngestionPage })),
);

function RouteFallback() {
  return (
    <div className="flex min-h-[40vh] items-center justify-center p-8 text-admin-text-muted">
      Loading…
    </div>
  );
}

export default function App() {
  return (
    <AdminAuthProvider>
      <BrowserRouter>
        <Suspense fallback={<RouteFallback />}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/forbidden" element={<ForbiddenPage />} />

            <Route element={<RequireSuperAdmin />}>
              <Route element={<AdminLayout />}>
                <Route index element={<DashboardPage />} />
                <Route path="fleet" element={<FleetPage />} />
                <Route path="passport" element={<PassportPage />} />
                <Route path="ledger" element={<LedgerPage />} />
                <Route path="ai/cases" element={<CaseMemoryPage />} />
                <Route path="ai/research" element={<ResearchIngestionPage />} />
              </Route>
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </BrowserRouter>
    </AdminAuthProvider>
  );
}
