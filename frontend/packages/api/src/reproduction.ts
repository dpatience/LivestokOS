/** Stage 5 reproduction/dairy — field names match backend schemas exactly. */

export type BreedingMethod = "ai" | "natural";
export type BreedingOutcome = "pending" | "confirmed_pregnant" | "failed";
export type GestationStatus = "active" | "calved" | "lost";
export type CalvingDifficulty = "easy" | "assisted" | "veterinary";
export type DryOffStatus = "scheduled" | "completed";

export interface BreedingRecord {
  id: number;
  cow_id: number;
  farm_id: number;
  insemination_date: string;
  method: BreedingMethod;
  sire_id: number | null;
  sire_reference: string | null;
  outcome: BreedingOutcome;
  confirmed_at: string | null;
  inserted_at: string;
}

export interface BreedingRecordPayload {
  cow_id: number;
  farm_id?: number;
  insemination_date: string;
  method: BreedingMethod;
  sire_id?: number;
  sire_reference?: string;
  outcome?: BreedingOutcome;
  confirmed_at?: string;
}

export interface Gestation {
  id: number;
  cow_id: number;
  farm_id: number;
  breeding_record_id: number;
  conception_date: string;
  expected_calving_date: string;
  actual_calving_date: string | null;
  status: GestationStatus;
  days_until_calving: number;
  inserted_at: string;
}

export interface LactationRecord {
  id: number;
  cow_id: number;
  farm_id: number;
  milking_date: string;
  yield_liters: number;
  fat_pct: number | null;
  protein_pct: number | null;
  source: string;
  inserted_at: string;
}

export interface LactationRecordPayload {
  cow_id: number;
  farm_id?: number;
  milking_date: string;
  yield_liters: number;
  fat_pct?: number;
  protein_pct?: number;
  source?: string;
}

export interface LactationSummary {
  total_liters: number;
  avg_daily_liters: number;
  peak_liters: number;
  record_count: number;
}

export interface DryOffSchedule {
  id: number;
  cow_id: number;
  farm_id: number;
  gestation_id: number;
  scheduled_dry_off_date: string;
  actual_dry_off_date: string | null;
  status: DryOffStatus;
  inserted_at: string;
}

export interface CalvingEvent {
  id: number;
  cow_id: number;
  farm_id: number;
  occurred_at: string;
  calf_id: number | null;
  birth_weight_kg: number | null;
  difficulty: CalvingDifficulty;
  notes: string | null;
  inserted_at: string;
}

export interface CalvingEventPayload {
  cow_id: number;
  farm_id?: number;
  occurred_at: string;
  calf_id?: number;
  birth_weight_kg?: number;
  difficulty: CalvingDifficulty;
  notes?: string;
}
