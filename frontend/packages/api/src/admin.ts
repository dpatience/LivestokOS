/** Admin cross-farm types — shapes from AdminController JSON. */

export interface AdminFarm {
  id: number;
  name: string;
  grazing_mode: string;
  location: string;
  unresolved_alerts: number;
  devices_total: number;
  devices_online: number;
}

export interface AdminDeviceCow {
  id: number;
  tag_id: string;
  name: string;
}

export interface AdminDevice {
  id: number;
  serial: string;
  hardware_type: string;
  status: string;
  last_seen_at: string | null;
  farm_id: number | null;
  farm_name: string | null;
  battery_level: number | null;
  paired: boolean;
  cow: AdminDeviceCow | null;
}

export type LedgerChainStatus = "valid" | "broken" | "empty";

export interface LedgerEntry {
  id: number;
  record_type: string;
  record_id: number;
  content_hash: string;
  previous_hash: string;
  chain_hash: string;
  inserted_at: string;
}

export interface FarmLedger {
  chain_status: LedgerChainStatus;
  entries: LedgerEntry[];
}

export interface DigitalPassport {
  version: string;
  generated_at: string;
  signature: string | null;
  farm: { id: number; name: string; grazing_mode: string };
  cow: { id: number; tag_id: string; name: string; breed: string };
  behavioral_history: unknown[];
  rotation_log: unknown[];
  accumulated_carbon_credit_tco2e: number;
  feed_efficiency_index: number | null;
  ledger_reference: { entry_id: number; chain_hash: string; inserted_at: string } | null;
}

/** Confirmed from User.changeset — only super_admin has cross-farm admin API access. */
export type UserRole = "super_admin" | "farm_owner" | "farm_worker";

export interface ConfirmedCaseRecord {
  id: number;
  farm_id: number;
  farm_name: string | null;
  cow_id: number;
  cow_name: string | null;
  cow_tag_id: string | null;
  situation_summary: string;
  assistant_answer: string | null;
  confirmed_at: string;
  confirmed_by_user_id: number | null;
  inserted_at: string;
}

export interface ResearchArticleRecord {
  id: number;
  title: string;
  authors: string | null;
  source: string | null;
  url: string | null;
  published_date: string | null;
  abstract_summary: string | null;
  inserted_at: string;
}

export type IngestionJobState =
  | "never_run"
  | "available"
  | "scheduled"
  | "executing"
  | "retryable"
  | "completed"
  | "cancelled"
  | "discarded";

export interface IngestionJobStatus {
  id?: number;
  state: IngestionJobState;
  inserted_at: string | null;
  completed_at: string | null;
  attempted_at: string | null;
  errors: unknown[];
}

export interface IngestionStatus {
  job: IngestionJobStatus;
  article_count: number;
}

export interface RevokeCaseResult {
  id: number;
  confirmed_at: string | null;
  revoked: boolean;
}

export interface TriggerIngestionResult {
  job_id: number;
  state: string;
  inserted_at: string;
}

export function isSuperAdmin(role: string): boolean {
  return role === "super_admin";
}
