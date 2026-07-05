import type { IngestionJobState } from "@livestok/api";
import type { ReactNode } from "react";
import { AlertTriangle, CheckCircle2, Loader2 } from "@livestok/ui";

export type IngestionDisplayStatus = "success" | "error" | "in_progress" | "idle";

export function ingestionDisplayStatus(state: IngestionJobState): IngestionDisplayStatus {
  switch (state) {
    case "completed":
      return "success";
    case "executing":
    case "scheduled":
    case "available":
    case "retryable":
      return "in_progress";
    case "discarded":
    case "cancelled":
      return "error";
    case "never_run":
    default:
      return "idle";
  }
}

export function ingestionStatusLabel(state: IngestionJobState): string {
  switch (state) {
    case "completed":
      return "Last run succeeded";
    case "executing":
      return "In progress";
    case "scheduled":
      return "Scheduled";
    case "available":
      return "Queued";
    case "retryable":
      return "Retrying";
    case "discarded":
      return "Failed (discarded)";
    case "cancelled":
      return "Cancelled";
    case "never_run":
      return "No runs yet";
    default:
      return state;
  }
}

export function ingestionStatusTone(
  status: IngestionDisplayStatus,
): "success" | "warning" | "danger" | "muted" {
  switch (status) {
    case "success":
      return "success";
    case "error":
      return "danger";
    case "in_progress":
      return "warning";
    case "idle":
      return "muted";
  }
}

export function ingestionStatusIcon(status: IngestionDisplayStatus): ReactNode {
  switch (status) {
    case "success":
      return <CheckCircle2 size={16} />;
    case "error":
      return <AlertTriangle size={16} />;
    case "in_progress":
      return <Loader2 size={16} className="animate-spin" />;
    case "idle":
      return <Loader2 size={16} className="opacity-40" />;
  }
}

export function formatIngestionErrors(errors: unknown[]): string | null {
  if (!errors.length) return null;
  return errors
    .map((e) => (typeof e === "string" ? e : JSON.stringify(e)))
    .join("; ");
}
