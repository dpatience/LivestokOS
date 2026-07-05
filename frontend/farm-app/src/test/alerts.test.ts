import { describe, expect, it } from "vitest";
import {
  alertVisualGroup,
  effectiveSeverityScore,
  featureEnabled,
  filterGrazingCoachAlerts,
  filterUrgentAlerts,
  isHighSeverityAlert,
  type Alert,
} from "@livestok/api";

function mockAlert(overrides: Partial<Alert>): Alert {
  return {
    id: 1,
    type: "HEALTH_RISK",
    message: "test",
    is_resolved: false,
    severity: "warning",
    priority: "medium",
    cow_id: 1,
    farm_id: 1,
    severity_score: 45,
    inserted_at: "2026-07-05T10:00:00Z",
    ...overrides,
  };
}

describe("alert classification", () => {
  it("separates urgent calving/health from grazing suggestions", () => {
    const urgent = mockAlert({ type: "CALVING_IMMINENT", severity_score: 100 });
    const grazing = mockAlert({ type: "GRAZING_RECOMMENDATION", severity_score: 20 });

    expect(alertVisualGroup(urgent)).toBe("urgent");
    expect(alertVisualGroup(grazing)).toBe("grazing");
    expect(filterUrgentAlerts([grazing, urgent]).map((a) => a.type)).toEqual(["CALVING_IMMINENT"]);
    expect(filterGrazingCoachAlerts([grazing, urgent]).map((a) => a.type)).toEqual([
      "GRAZING_RECOMMENDATION",
    ]);
  });

  it("uses score fallback when backend returns 0 for uppercase types", () => {
    const alert = mockAlert({ type: "CALVING_IMMINENT", severity_score: 0 });
    expect(effectiveSeverityScore(alert)).toBe(100);
  });

  it("flags high severity for critical calving and health", () => {
    expect(isHighSeverityAlert(mockAlert({ type: "HEALTH_RISK", severity_score: 45 }))).toBe(true);
    expect(
      isHighSeverityAlert(mockAlert({ type: "GRAZING_RECOMMENDATION", severity_score: 20 })),
    ).toBe(false);
  });
});

describe("grazing coach visibility from farm grazing_mode", () => {
  it("is absent for zero_grazing (mirrors backend feature_enabled?)", () => {
    expect(featureEnabled("zero_grazing", "grazing_coach")).toBe(false);
    expect(featureEnabled("pasture", "grazing_coach")).toBe(true);
    expect(featureEnabled("mixed", "grazing_coach")).toBe(true);
  });
});
