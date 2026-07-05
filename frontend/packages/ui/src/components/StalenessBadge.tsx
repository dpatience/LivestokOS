import { Clock } from "lucide-react";

export interface StalenessBadgeProps {
  fetchedAt: number;
  isStale: boolean;
  variant?: "farm" | "admin";
}

function formatAge(fetchedAt: number): string {
  const mins = Math.floor((Date.now() - fetchedAt) / 60_000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  return `${hrs}h ago`;
}

export function StalenessBadge({ fetchedAt, isStale, variant = "farm" }: StalenessBadgeProps) {
  const tone =
    variant === "farm"
      ? isStale
        ? "border-farm-accent/50 bg-farm-accent/10 text-farm-accent"
        : "border-farm-border bg-farm-surface-alt text-farm-text-muted"
      : isStale
        ? "border-admin-accent/40 bg-admin-accent/5 text-admin-accent"
        : "border-admin-border bg-admin-surface-alt text-admin-text-muted";

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold ${tone}`}
      role="status"
      aria-live="polite"
    >
      <Clock size={14} aria-hidden />
      {isStale ? "Offline — showing cached data from " : "Updated "}
      {formatAge(fetchedAt)}
    </span>
  );
}
