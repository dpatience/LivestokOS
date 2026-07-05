import { Link } from "react-router-dom";
import { farmLinkInline } from "@livestok/ui";
import { AlertsInbox } from "../components/AlertsInbox";
import { PushNotificationSettings } from "../components/PushNotificationSettings";
import { useAlerts } from "../hooks/useAlerts";

export function AlertsPage() {
  const { alerts, loading, resolve } = useAlerts(30_000);

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Alerts inbox</h2>
      <p className="text-sm text-farm-text-muted">
        Sorted by backend severity score (calving/health first). Grazing suggestions are debounced
        24h server-side.
      </p>

      <PushNotificationSettings />

      {loading ? (
        <p className="text-sm text-farm-text-muted">Loading alerts…</p>
      ) : (
        <AlertsInbox alerts={alerts} onResolve={(id) => void resolve(id)} />
      )}

      <Link to="/reproduction" className={`text-sm ${farmLinkInline}`}>
        Reproduction &amp; dairy module
      </Link>
    </div>
  );
}
