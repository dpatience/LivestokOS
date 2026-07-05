import type { Alert } from "@livestok/api";
import { filterGrazingCoachAlerts, filterUrgentAlerts } from "@livestok/api";
import { AlertCard } from "./AlertCard";

interface AlertsInboxProps {
  alerts: Alert[];
  onResolve?: (id: number) => void;
  limit?: number;
}

export function AlertsInbox({ alerts, onResolve, limit }: AlertsInboxProps) {
  const urgent = filterUrgentAlerts(alerts);
  const grazing = filterGrazingCoachAlerts(alerts);
  const showUrgent = limit ? urgent.slice(0, limit) : urgent;
  const showGrazing = limit ? grazing.slice(0, Math.max(0, limit - showUrgent.length)) : grazing;

  if (alerts.length === 0) {
    return <p className="text-sm text-farm-text-muted">No unresolved alerts.</p>;
  }

  return (
    <div className="space-y-6">
      {showUrgent.length > 0 ? (
        <section aria-labelledby="urgent-alerts-heading">
          <h3 id="urgent-alerts-heading" className="mb-2 text-sm font-bold uppercase text-farm-danger">
            Calving &amp; health
          </h3>
          <ul className="space-y-2">
            {showUrgent.map((a) => (
              <li key={a.id}>
                <AlertCard alert={a} onResolve={onResolve} />
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {showGrazing.length > 0 ? (
        <section aria-labelledby="grazing-alerts-heading">
          <h3 id="grazing-alerts-heading" className="mb-2 text-sm font-bold uppercase text-farm-primary">
            Grazing suggestions
          </h3>
          <ul className="space-y-2">
            {showGrazing.map((a) => (
              <li key={a.id}>
                <AlertCard alert={a} onResolve={onResolve} />
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
