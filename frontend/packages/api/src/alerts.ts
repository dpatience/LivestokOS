/** Alert types and classification — mirrors backend Alert.score_for_type/1. */

export interface Alert {
  id: number;
  type: string;
  message: string;
  is_resolved: boolean;
  severity: "info" | "warning" | "critical" | string;
  priority: "low" | "medium" | "high" | "critical" | string;
  cow_id: number | null;
  farm_id: number | null;
  severity_score: number;
  inserted_at: string;
}

export interface AlertUpdatePayload {
  is_resolved?: boolean;
  message?: string;
  severity?: string;
  priority?: string;
}

/** Visual/structural groups — not just color (colorblind-safe icon + shape). */
export type AlertVisualGroup = "urgent" | "grazing";

export type AlertDomain = "calving" | "health" | "reproduction" | "grazing" | "other";

const GRAZING_TYPES = new Set([
  "GRAZING_RECOMMENDATION",
  "grazing_recommendation",
  "OVERGRAZING",
  "METHANE_RISK",
  "shade_water_alert",
  "ndvi_lick_block",
]);

const CALVING_TYPES = new Set([
  "CALVING_IMMINENT",
  "CALVING_OVERDUE",
  "CALVING_COMPLETE",
  "calving_imminent",
  "overdue_gestation",
]);

const HEALTH_TYPES = new Set(["HEALTH_RISK", "heat_stress"]);

const REPRO_TYPES = new Set(["ESTRUS_PROXY", "estrus_proxy", "DRY_OFF_DUE"]);

/** Client-side score fallback when backend returns 0 due to type casing mismatch. */
const SCORE_FALLBACK: Record<string, number> = {
  CALVING_IMMINENT: 100,
  CALVING_OVERDUE: 80,
  CALVING_COMPLETE: 100,
  calving_imminent: 100,
  overdue_gestation: 80,
  ESTRUS_PROXY: 70,
  estrus_proxy: 70,
  GEOFENCE_BREACH: 60,
  HEALTH_RISK: 45,
  METHANE_RISK: 40,
  OVERGRAZING: 35,
  GRAZING_RECOMMENDATION: 20,
  grazing_recommendation: 20,
  DRY_OFF_DUE: 70,
};

export function effectiveSeverityScore(alert: Alert): number {
  if (alert.severity_score > 0) return alert.severity_score;
  return SCORE_FALLBACK[alert.type] ?? 0;
}

export function alertDomain(alert: Alert): AlertDomain {
  if (CALVING_TYPES.has(alert.type)) return "calving";
  if (HEALTH_TYPES.has(alert.type)) return "health";
  if (REPRO_TYPES.has(alert.type)) return "reproduction";
  if (GRAZING_TYPES.has(alert.type)) return "grazing";
  return "other";
}

/** Urgent = calving/health/reproduction; Grazing = routine paddock suggestions. */
export function alertVisualGroup(alert: Alert): AlertVisualGroup {
  const domain = alertDomain(alert);
  return domain === "grazing" ? "grazing" : "urgent";
}

export function isHighSeverityAlert(alert: Alert): boolean {
  return (
    alert.severity === "critical" ||
    alert.priority === "critical" ||
    effectiveSeverityScore(alert) >= 45
  );
}

export function isGrazingCoachAlert(alert: Alert): boolean {
  return GRAZING_TYPES.has(alert.type);
}

export function sortAlertsBySeverity(alerts: Alert[]): Alert[] {
  return [...alerts].sort((a, b) => {
    const scoreDiff = effectiveSeverityScore(b) - effectiveSeverityScore(a);
    if (scoreDiff !== 0) return scoreDiff;
    return new Date(b.inserted_at).getTime() - new Date(a.inserted_at).getTime();
  });
}

export function filterGrazingCoachAlerts(alerts: Alert[]): Alert[] {
  return sortAlertsBySeverity(alerts.filter(isGrazingCoachAlert));
}

export function filterUrgentAlerts(alerts: Alert[]): Alert[] {
  return sortAlertsBySeverity(alerts.filter((a) => alertVisualGroup(a) === "urgent"));
}
