/** Stage 6 AI vet consult — mirrors ConsultSession HTTP API (non-streaming JSON). */

export type ConsultSourceType =
  | "cow_own_data"
  | "cross_farm_pattern"
  | "research_corpus"
  | "unknown";

export interface ConsultSource {
  source_type: ConsultSourceType | string;
  data: Record<string, unknown>;
}

export interface ConsultAttribution {
  source_type: ConsultSourceType | string;
  count: number;
}

export interface ConfirmedCaseRef {
  confirmed_at: string;
  situation_summary: string;
}

export interface ConsultReply {
  response: string;
  sources: ConsultSource[];
  insufficient_data: boolean;
  confirmed_case_reused: boolean;
  confirmed_case: ConfirmedCaseRef | null;
  recommended_next_steps: string[] | null;
  attributions: ConsultAttribution[];
}

export interface ConsultSession {
  session_id: string;
  cow_id: number;
  farm_id: number;
}

export interface ConsultHistoryEntry {
  role: "user" | "assistant";
  content: string;
  timestamp: string;
  metadata?: Omit<ConsultReply, "response">;
}

export const SOURCE_LABELS: Record<string, string> = {
  cow_own_data: "This cow's data",
  cross_farm_pattern: "Cross-farm pattern",
  research_corpus: "Research citation",
  unknown: "Unknown source",
};

export function sourceLabel(type: string): string {
  if (type === "cow_own_data") return SOURCE_LABELS.cow_own_data;
  if (type === "cross_farm_pattern") return SOURCE_LABELS.cross_farm_pattern;
  if (type === "research_corpus") return SOURCE_LABELS.research_corpus;
  return SOURCE_LABELS.unknown;
}

/** Detect insufficient-data replies when flag missing (legacy string match). */
export function isInsufficientReply(reply: ConsultReply): boolean {
  if (reply.insufficient_data) return true;
  return reply.response.startsWith("The data needed to answer this question is not yet available");
}

/** Detect vet-confirmed case reuse from structured flag or prose prefix. */
export function isConfirmedCaseReply(reply: ConsultReply): boolean {
  if (reply.confirmed_case_reused) return true;
  return reply.response.startsWith("Similar confirmed case found:");
}

export function formatConfirmedDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  } catch {
    return iso;
  }
}
