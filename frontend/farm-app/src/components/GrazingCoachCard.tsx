import type { Alert } from "@livestok/api";
import { filterGrazingCoachAlerts } from "@livestok/api";
import { Card, Leaf } from "@livestok/ui";
import { AlertCard } from "./AlertCard";

interface GrazingCoachCardProps {
  /** From GET /api/farms/:id — grazing_mode field drives visibility upstream. */
  alerts: Alert[];
  onResolve?: (id: number) => void;
}

/**
 * Paddock recommendations surface via GRAZING_RECOMMENDATION / OVERGRAZING /
 * METHANE_RISK alerts (no dedicated /api/grazing_coach endpoint).
 */
export function GrazingCoachCard({ alerts, onResolve }: GrazingCoachCardProps) {
  const grazingAlerts = filterGrazingCoachAlerts(alerts);

  return (
    <Card variant="farm" className="border-2 border-farm-primary/30">
      <div className="mb-3 flex items-center gap-2">
        <span
          className="flex h-10 w-10 items-center justify-center rounded-full bg-farm-primary/15 text-farm-primary"
          aria-hidden
        >
          <Leaf size={20} />
        </span>
        <div>
          <h2 className="text-lg font-bold text-farm-text">Grazing Coach</h2>
          <p className="text-xs text-farm-text-muted">Paddock recommendations from satellite + rotation data</p>
        </div>
      </div>

      {grazingAlerts.length === 0 ? (
        <p className="text-sm text-farm-text-muted">
          No active paddock recommendations. The backend debounces duplicate alerts for 24 hours.
        </p>
      ) : (
        <ul className="space-y-2">
          {grazingAlerts.map((a) => (
            <li key={a.id}>
              <AlertCard alert={a} onResolve={onResolve} compact />
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}
