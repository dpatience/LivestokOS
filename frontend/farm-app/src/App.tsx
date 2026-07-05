import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import { FarmLayout } from "./components/Layout";
import { RequireAuth } from "./components/RequireAuth";
import { CowFormPage } from "./pages/CowFormPage";
import { CowProfilePage } from "./pages/CowProfilePage";
import { DevicesPage } from "./pages/DevicesPage";
import { PairDevicePage } from "./pages/PairDevicePage";
import { NoFarmPage } from "./pages/NoFarmPage";
import { GeofencesPage } from "./pages/GeofencesPage";
import { HerdListPage } from "./pages/HerdListPage";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { RegisterPage } from "./pages/RegisterPage";

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />

          <Route element={<RequireAuth />}>
            <Route path="/setup" element={<NoFarmPage />} />
            <Route element={<FarmLayout />}>
              <Route index element={<HomePage />} />
              <Route path="herd" element={<HerdListPage />} />
              <Route path="herd/new" element={<CowFormPage />} />
              <Route path="herd/:id" element={<CowProfilePage />} />
              <Route path="herd/:id/edit" element={<CowFormPage />} />
              <Route path="geofences" element={<GeofencesPage />} />
              <Route path="devices" element={<DevicesPage />} />
              <Route path="devices/pair" element={<PairDevicePage />} />
              <Route path="devices/:id/repair" element={<PairDevicePage />} />
            </Route>
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
