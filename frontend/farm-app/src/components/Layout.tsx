import { AppShell, Button } from "@livestok/ui";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useFarmFeatures } from "../hooks/useFarmFeatures";

const navClass = ({ isActive }: { isActive: boolean }) =>
  `tap-target flex flex-1 flex-col items-center justify-center gap-1 text-xs font-semibold ${
    isActive ? "text-farm-primary" : "text-farm-text-muted"
  }`;

export function FarmLayout() {
  const { user, farm, logout } = useAuth();
  const navigate = useNavigate();
  const { showGeofences } = useFarmFeatures();

  return (
    <div className="flex min-h-dvh flex-col bg-farm-surface text-farm-text">
      <header className="bg-farm-primary px-4 py-3 text-white shadow-sm">
        <div className="flex items-center justify-between gap-2">
          <div>
            <p className="text-lg font-bold">{farm?.name ?? "LivestokOS Farm"}</p>
            <p className="text-sm opacity-90">{user?.name}</p>
          </div>
          <Button
            variant="farm"
            className="!min-h-10 !min-w-auto bg-white/15 px-3 text-sm hover:bg-white/25"
            onClick={() => {
              logout();
              navigate("/login");
            }}
          >
            Sign out
          </Button>
        </div>
      </header>

      <main className="flex-1 overflow-y-auto p-4 pb-24">
        <Outlet />
      </main>

      <nav className="fixed inset-x-0 bottom-0 border-t border-farm-border bg-farm-surface shadow-[0_-4px_12px_rgba(0,0,0,0.08)]">
        <div className="mx-auto flex max-w-lg">
          <NavLink to="/" end className={navClass}>
            <span aria-hidden>🏠</span>
            Home
          </NavLink>
          <NavLink to="/herd" className={navClass}>
            <span aria-hidden>🐄</span>
            Herd
          </NavLink>
          {showGeofences ? (
            <NavLink to="/geofences" className={navClass}>
              <span aria-hidden>🗺️</span>
              Paddocks
            </NavLink>
          ) : null}
          <NavLink to="/devices" className={navClass}>
            <span aria-hidden>📡</span>
            Devices
          </NavLink>
        </div>
      </nav>
    </div>
  );
}

export function AuthLayout({ title, children }: { title: string; children: React.ReactNode }) {
  return <AppShell variant="farm" title={title}>{children}</AppShell>;
}
