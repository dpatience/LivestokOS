import { BottomNav, Button, NavItem } from "@livestok/ui";
import {
  Activity,
  ClipboardList,
  Home,
  Map,
  NotebookPen,
  Radio,
  Stethoscope,
} from "@livestok/ui";
import { useAuth } from "../context/AuthContext";
import { useFarmFeatures } from "../hooks/useFarmFeatures";
import { Outlet, useNavigate } from "react-router-dom";

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

      <BottomNav variant="farm">
        <NavItem to="/consult" icon={<Stethoscope size={20} />} label="AI" variant="farm" />
        <NavItem to="/" end icon={<NotebookPen size={20} />} label="Diary" variant="farm" />
        <NavItem to="/herd" icon={<Activity size={20} />} label="Herd" variant="farm" />
        {showGeofences ? (
          <NavItem to="/paddocks" icon={<Map size={20} />} label="Paddocks" variant="farm" />
        ) : null}
        <NavItem to="/devices" icon={<Radio size={20} />} label="Devices" variant="farm" />
        <NavItem to="/home" icon={<Home size={20} />} label="Home" variant="farm" />
        <NavItem to="/alerts" icon={<ClipboardList size={20} />} label="Alerts" variant="farm" />
      </BottomNav>
    </div>
  );
}

export function AuthLayout({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="min-h-dvh bg-farm-surface p-4">
      <h1 className="mb-4 text-lg font-bold">{title}</h1>
      {children}
    </div>
  );
}
