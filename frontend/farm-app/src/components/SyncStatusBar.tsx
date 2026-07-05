import { Button } from "@livestok/ui";
import type { OutboxStatus } from "../db/outbox";

export interface SyncSummary {
  queued: number;
  syncing: number;
  synced: number;
  failed: number;
  online: boolean;
}

interface SyncStatusBarProps {
  summary: SyncSummary;
  flushing: boolean;
  onRetry: () => void;
}

export function SyncStatusBar({ summary, flushing, onRetry }: SyncStatusBarProps) {
  const pending = summary.queued + summary.failed;
  const label = !summary.online
    ? "Offline — entries will queue"
    : pending > 0
      ? `${pending} pending sync`
      : summary.syncing > 0
        ? "Syncing…"
        : "All entries synced";

  const tone =
    !summary.online || summary.failed > 0
      ? "border-farm-accent bg-farm-accent/10 text-farm-accent"
      : pending > 0
        ? "border-farm-primary bg-farm-primary/10 text-farm-primary"
        : "border-farm-success bg-farm-success/10 text-farm-success";

  return (
    <div className={`flex items-center justify-between gap-2 rounded-farm border px-3 py-2 text-sm font-semibold ${tone}`}>
      <span role="status">{flushing ? "Syncing…" : label}</span>
      {pending > 0 && summary.online ? (
        <Button
          variant="farm"
          type="button"
          className="!min-h-10 !min-w-auto px-3 text-sm"
          disabled={flushing}
          onClick={onRetry}
        >
          Retry sync
        </Button>
      ) : null}
    </div>
  );
}

export function statusLabel(status: OutboxStatus): string {
  switch (status) {
    case "queued":
      return "Queued";
    case "syncing":
      return "Syncing";
    case "synced":
      return "Synced";
    case "failed":
      return "Failed";
  }
}
