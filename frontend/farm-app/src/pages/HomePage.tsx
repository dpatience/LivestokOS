import { Card, Droplets, farmCardRow, farmLinkInline, farmLinkPrimary, farmLinkSecondary } from "@livestok/ui";
import { Link } from "react-router-dom";
import { AlertsInbox } from "../components/AlertsInbox";
import { GrazingCoachCard } from "../components/GrazingCoachCard";
import { GrazingModeBadge } from "../components/GrazingModePicker";
import { useAlerts } from "../hooks/useAlerts";
import { useGrazingCoachVisible } from "../hooks/useGrazingCoachVisible";
import { useAuth } from "../context/AuthContext";

export function HomePage() {
  const { farm } = useAuth();
  const { alerts, resolve } = useAlerts();
  const showGrazingCoach = useGrazingCoachVisible();

  if (!farm) {
    return (
      <Card variant="farm">
        <p className="text-farm-text-muted">No farm linked to your account.</p>
      </Card>
    );
  }

  const unresolvedCount = alerts.length;

  return (
    <div className="space-y-4">
      <GrazingModeBadge mode={farm.grazing_mode} />

      <div className="flex items-center justify-between gap-2">
        <h2 className="text-xl font-bold">Farm overview</h2>
        <Link
          to="/alerts"
          className={`${farmLinkSecondary} !min-h-10 rounded-full !px-3 !py-1 text-sm !font-bold !text-farm-danger hover:!border-farm-danger/40 hover:!bg-farm-danger/10`}
        >
          {unresolvedCount} alert{unresolvedCount === 1 ? "" : "s"}
        </Link>
      </div>

      <Card variant="farm">
        <div className="mb-2 flex items-center justify-between">
          <h3 className="font-bold">Recent alerts</h3>
          <Link to="/alerts" className={`text-sm ${farmLinkInline}`}>
            View all
          </Link>
        </div>
        <AlertsInbox alerts={alerts} onResolve={(id) => void resolve(id)} limit={4} />
      </Card>

      {showGrazingCoach ? (
        <GrazingCoachCard alerts={alerts} onResolve={(id) => void resolve(id)} />
      ) : null}

      <Link to="/reproduction" className={`${farmCardRow} flex flex-col items-center justify-center py-4`}>
        <Droplets size={28} className="mb-1 text-farm-primary" aria-hidden />
        <span className="font-semibold">Reproduction &amp; dairy</span>
      </Link>

      <div className="grid gap-3">
        <Link to="/herd" className={`${farmLinkPrimary} w-full py-3 text-sm`}>
          Manage herd
        </Link>
        <Link to="/devices" className={`${farmLinkSecondary} w-full py-3 text-sm`}>
          Necklace devices
        </Link>
      </div>

      {farm.grazing_mode === "zero_grazing" ? (
        <p className="text-xs text-farm-text-muted">
          Grazing Coach is not shown — backend returns grazing_mode &quot;zero_grazing&quot; and
          disables :grazing_coach for this farm.
        </p>
      ) : null}
    </div>
  );
}
