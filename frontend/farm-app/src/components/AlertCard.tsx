import type { Alert } from "@livestok/api";
import { alertDomain, alertVisualGroup, effectiveSeverityScore } from "@livestok/api";
import {
  AlertTriangle,
  Baby,
  Button,
  Heart,
  Leaf,
  Stethoscope,
  type LucideIcon,
} from "@livestok/ui";

interface AlertCardProps {
  alert: Alert;
  onResolve?: (id: number) => void;
  compact?: boolean;
}

function UrgentIcon({ domain }: { domain: ReturnType<typeof alertDomain> }) {
  let Icon: LucideIcon = AlertTriangle;
  if (domain === "calving") Icon = Baby;
  else if (domain === "health") Icon = Stethoscope;
  else if (domain === "reproduction") Icon = Heart;

  return (
    <span
      className="flex h-11 w-11 shrink-0 items-center justify-center bg-farm-danger/15 text-farm-danger"
      style={{ clipPath: "polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%)" }}
      data-visual-shape="diamond"
      aria-hidden
    >
      <Icon size={22} strokeWidth={2.25} />
    </span>
  );
}

export function AlertCard({ alert, onResolve, compact }: AlertCardProps) {
  const group = alertVisualGroup(alert);
  const domain = alertDomain(alert);
  const score = effectiveSeverityScore(alert);

  if (group === "grazing") {
    return (
      <article
        className="flex gap-3 rounded-full border-2 border-dashed border-farm-primary/40 bg-farm-primary/5 px-4 py-3 transition-colors hover:border-farm-primary/60 hover:bg-farm-primary/10"
        aria-label={`Grazing suggestion: ${alert.message}`}
        data-visual-shape="pill"
      >
        <span
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-farm-primary/15 text-farm-primary"
          data-visual-shape="circle"
          aria-hidden
        >
          <Leaf size={20} strokeWidth={2.25} />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold uppercase tracking-wide text-farm-primary">Grazing suggestion</p>
          <p className={`text-farm-text ${compact ? "text-sm" : "text-base"}`}>{alert.message}</p>
          {!compact ? (
            <p className="mt-1 text-xs text-farm-text-muted">
              Score {score} · {alert.type} · debounced 24h on backend
            </p>
          ) : null}
        </div>
        {onResolve ? (
          <Button
            variant="farm"
            type="button"
            className="!min-h-10 shrink-0 self-center px-3 text-xs"
            onClick={() => onResolve(alert.id)}
          >
            Dismiss
          </Button>
        ) : null}
      </article>
    );
  }

  const label =
    domain === "calving"
      ? "Calving alert"
      : domain === "health"
        ? "Health alert"
        : domain === "reproduction"
          ? "Reproduction alert"
          : "Urgent alert";

  return (
    <article
      className="relative flex gap-3 border-l-4 border-farm-danger bg-farm-danger/5 py-3 pl-4 pr-3 transition-colors hover:bg-farm-danger/10"
      style={{ clipPath: "polygon(0 0, 100% 0, 100% calc(100% - 12px), calc(100% - 12px) 100%, 0 100%)" }}
      aria-label={`${label}: ${alert.message}`}
      data-visual-shape="notched-urgent"
    >
      <UrgentIcon domain={domain} />
      <div className="min-w-0 flex-1">
        <p className="text-xs font-bold uppercase tracking-wide text-farm-danger">{label}</p>
        <p className={`font-semibold text-farm-text ${compact ? "text-sm" : "text-base"}`}>
          {alert.message}
        </p>
        {!compact ? (
          <p className="mt-1 text-xs text-farm-text-muted">
            Priority {alert.priority} · severity score {score}
            {alert.cow_id ? ` · cow #${alert.cow_id}` : ""}
          </p>
        ) : null}
      </div>
      {onResolve ? (
        <Button
          variant="farm"
          type="button"
          className="!min-h-10 shrink-0 self-center px-3 text-xs"
          onClick={() => onResolve(alert.id)}
        >
          Resolve
        </Button>
      ) : null}
    </article>
  );
}
