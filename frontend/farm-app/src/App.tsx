import { lazy, Suspense } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import { FarmLayout } from "./components/Layout";
import { RequireAuth } from "./components/RequireAuth";
import { LoginPage } from "./pages/LoginPage";
import { RegisterPage } from "./pages/RegisterPage";

const DiaryPage = lazy(() => import("./pages/DiaryPage").then((m) => ({ default: m.DiaryPage })));
const HomePage = lazy(() => import("./pages/HomePage").then((m) => ({ default: m.HomePage })));
const ConsultPage = lazy(() => import("./pages/ConsultPage").then((m) => ({ default: m.ConsultPage })));
const AlertsPage = lazy(() => import("./pages/AlertsPage").then((m) => ({ default: m.AlertsPage })));
const ReproductionPage = lazy(() =>
  import("./pages/ReproductionPage").then((m) => ({ default: m.ReproductionPage })),
);
const HerdListPage = lazy(() => import("./pages/HerdListPage").then((m) => ({ default: m.HerdListPage })));
const CowFormPage = lazy(() => import("./pages/CowFormPage").then((m) => ({ default: m.CowFormPage })));
const CowProfilePage = lazy(() =>
  import("./pages/CowProfilePage").then((m) => ({ default: m.CowProfilePage })),
);
const PaddockPage = lazy(() => import("./pages/PaddockPage").then((m) => ({ default: m.PaddockPage })));
const DevicesPage = lazy(() => import("./pages/DevicesPage").then((m) => ({ default: m.DevicesPage })));
const PairDevicePage = lazy(() => import("./pages/PairDevicePage").then((m) => ({ default: m.PairDevicePage })));
const NoFarmPage = lazy(() => import("./pages/NoFarmPage").then((m) => ({ default: m.NoFarmPage })));

function RouteFallback() {
  return (
    <div className="flex min-h-[40vh] items-center justify-center p-8 text-farm-text-muted">
      Loading…
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Suspense fallback={<RouteFallback />}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />

            <Route element={<RequireAuth />}>
              <Route path="/setup" element={<NoFarmPage />} />
              <Route element={<FarmLayout />}>
                <Route index element={<DiaryPage />} />
                <Route path="home" element={<HomePage />} />
                <Route path="consult" element={<ConsultPage />} />
                <Route path="alerts" element={<AlertsPage />} />
                <Route path="reproduction" element={<ReproductionPage />} />
                <Route path="herd" element={<HerdListPage />} />
                <Route path="herd/new" element={<CowFormPage />} />
                <Route path="herd/:id" element={<CowProfilePage />} />
                <Route path="herd/:id/edit" element={<CowFormPage />} />
                <Route path="paddocks" element={<PaddockPage />} />
                <Route path="geofences" element={<Navigate to="/paddocks" replace />} />
                <Route path="devices" element={<DevicesPage />} />
                <Route path="devices/pair" element={<PairDevicePage />} />
                <Route path="devices/:id/repair" element={<PairDevicePage />} />
              </Route>
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </BrowserRouter>
    </AuthProvider>
  );
}
