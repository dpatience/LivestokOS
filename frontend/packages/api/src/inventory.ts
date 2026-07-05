/** Matches FarmJSON — grazing_mode serializes as string from Ecto.Enum */
export type GrazingMode = "pasture" | "zero_grazing" | "mixed";

export interface Farm {
  id: number;
  name: string;
  grazing_mode: GrazingMode;
  location: string;
}

export interface FarmPayload {
  name: string;
  location: string;
  grazing_mode?: GrazingMode;
}

/** Matches CowJSON.data — note backend gaps documented in ARCHITECTURE */
export interface Cow {
  id: number;
  name: string;
  age: number;
  breed: string;
  weight: number;
  healthStatus: string;
}

/** Writable cow fields per Cow.changeset/2 */
export interface CowPayload {
  tag_id: string;
  name: string;
  breed: string;
  birth_date: string;
  status: string;
  farm_id?: number;
  sex?: "male" | "female" | "unknown";
}

/**
 * Backend geometry format (verified in GeofenceEnforcerTest) — NOT standard GeoJSON.
 * Ring of [lng, lat] pairs; first point repeated at end to close.
 */
export interface GeofencePolygonGeometry {
  type: "polygon";
  coordinates: [number, number][];
}

export interface Geofence {
  id: number;
  name: string;
  enforcement_scope: string;
  geometry: GeofencePolygonGeometry | Record<string, unknown>;
  is_active: boolean;
  description: string | null;
  inserted_at: string;
}

export interface GeofencePayload {
  name: string;
  enforcement_scope: string;
  geometry: GeofencePolygonGeometry;
  farm_id?: number;
  is_active?: boolean;
  description?: string;
}

export interface DeviceCowSummary {
  id: number;
  tag_id: string;
  name: string;
  farm_id: number;
}

export interface Device {
  id: number;
  serial: string;
  hardware_type: string;
  firmware_version: string | null;
  status: string;
  last_seen_at: string | null;
  metadata: Record<string, unknown>;
  cow: DeviceCowSummary | null;
  farm_id: number | null;
}

/** Writable device fields per Device.changeset/2 */
export interface DevicePayload {
  serial: string;
  hardware_type: string;
  firmware_version?: string;
  status?: string;
  farm_id?: number;
  /** Set to null to unpair (verified: Device.changeset casts cow_id) */
  cow_id?: number | null;
  metadata?: Record<string, unknown>;
}

export interface ListResponse<T> {
  data: T[];
}

export interface ItemResponse<T> {
  data: T;
}

export interface ChangesetErrors {
  errors: Record<string, string[]>;
}
