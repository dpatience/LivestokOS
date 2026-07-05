import { describe, expect, it } from "vitest";
import { ndviColor, ndviLabel, NDVI_HEALTH_LABELS } from "@livestok/api";

describe("paddock NDVI helpers", () => {
  it("maps health bands to labels", () => {
    expect(ndviLabel("healthy")).toBe(NDVI_HEALTH_LABELS.healthy);
    expect(ndviLabel(null)).toBe("No NDVI data");
  });

  it("maps health bands to colors", () => {
    expect(ndviColor("bare")).toMatch(/^#/);
    expect(ndviColor(undefined)).toBe("#94a3b8");
  });
});
