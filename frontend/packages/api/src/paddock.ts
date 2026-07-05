/** Paddock dashboard — mirrors GET /api/paddocks/overview and rotation endpoints. */

export type NdviHealth = "healthy" | "moderate" | "sparse" | "bare" | "stale";

export interface PaddockNdvi {
  score: number;
  captured_at: string;
  is_stale: boolean;
  health: NdviHealth;
}

export interface PaddockOverview {
  id: number;
  name: string;
  enforcement_scope: string;
  geometry: Record<string, unknown>;
  is_active: boolean;
  description: string | null;
  inserted_at: string;
  ndvi: PaddockNdvi | null;
  cow_count: number;
  cow_ids: number[];
  last_rotation_at: string | null;
}

export interface CowLocation {
  cow_id: number;
  name: string;
  tag_id: string;
  latitude: number | null;
  longitude: number | null;
  status: string;
  current_behavior: string | null;
  last_reading_at: string | null;
  speed_mps: number | null;
  source: "twin" | "sensor" | null;
}

export interface RotationResult {
  rotation_event_id: number;
  cows_rotated: number;
  from_paddock_id: number;
  to_paddock_id: number;
}

export const NDVI_HEALTH_COLORS: Record<NdviHealth, string> = {
  healthy: "#15803d",
  moderate: "#65a30d",
  sparse: "#d97706",
  bare: "#dc2626",
  stale: "#6b7280",
};

export const NDVI_HEALTH_LABELS: Record<NdviHealth, string> = {
  healthy: "Healthy pasture",
  moderate: "Moderate cover",
  sparse: "Sparse / recovering",
  bare: "Bare / overgrazed",
  stale: "NDVI data stale",
};

export function ndviColor(health: NdviHealth | null | undefined): string {
  if (!health) return "#94a3b8";
  return NDVI_HEALTH_COLORS[health];
}

export function ndviLabel(health: NdviHealth | null | undefined): string {
  if (!health) return "No NDVI data";
  return NDVI_HEALTH_LABELS[health];
}
