/** Diary entry types map to separate backend endpoints (no unified /api/diary). */

export interface FeedEventPayload {
  feed_type: string;
  quantity_kg: number;
  fed_at: string;
  cow_id: number;
  farm_id?: number;
  dry_matter_pct?: number;
  protein_pct?: number;
  inhibitor_added?: boolean;
  notes?: string;
}

export interface InhibitorDosePayload {
  inhibitor_type: string;
  dose_mg: number;
  administered_at: string;
  cow_id: number;
  effectiveness_pct?: number;
  notes?: string;
}

export interface GrazingEventPayload {
  zone_id: string;
  entered_at: string;
  cow_id: number;
  farm_id?: number;
  left_at?: string;
}

/** Backend gap: no health-observation create endpoint — uses PUT /api/cows/:id status update. */
export interface HealthObservationPayload {
  cow_id: number;
  status: string;
}

export type DiaryEntryType = "feed" | "inhibitor" | "grazing" | "health";

export interface FeedEvent {
  id: number;
  cow_id: number;
  farm_id: number | null;
  feed_type: string;
  quantity_kg: number;
  fed_at: string;
  notes: string | null;
}

export interface InhibitorDose {
  id: number;
  cow_id: number;
  inhibitor_type: string;
  dose_mg: number;
  administered_at: string;
  notes: string | null;
}

export interface GrazingEvent {
  id: number;
  cow_id: number;
  zone_id: string;
  entered_at: string;
  left_at: string | null;
}
