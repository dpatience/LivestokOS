import { describe, expect, it } from "vitest";
import {
  featureEnabled,
  geofenceGeometryToVertices,
  verticesToGeofenceGeometry,
} from "@livestok/api";

describe("featureEnabled", () => {
  it("enables pasture features for pasture and mixed", () => {
    expect(featureEnabled("pasture", "grazing_coach")).toBe(true);
    expect(featureEnabled("mixed", "satellite_ndvi")).toBe(true);
    expect(featureEnabled("zero_grazing", "grazing_coach")).toBe(false);
  });

  it("enables zero-grazing features for zero_grazing and mixed", () => {
    expect(featureEnabled("zero_grazing", "rfid_inhibitor_dosing")).toBe(true);
    expect(featureEnabled("mixed", "bms_climate_control")).toBe(true);
    expect(featureEnabled("pasture", "rfid_inhibitor_dosing")).toBe(false);
  });
});

describe("geofence geometry", () => {
  it("closes polygon ring and uses lng,lat order", () => {
    const geometry = verticesToGeofenceGeometry([
      { lng: -1, lat: -1 },
      { lng: 1, lat: -1 },
      { lng: 1, lat: 1 },
    ]);
    expect(geometry.type).toBe("polygon");
    expect(geometry.coordinates[0]).toEqual([-1, -1]);
    expect(geometry.coordinates.at(-1)).toEqual([-1, -1]);
  });

  it("round-trips vertices without closing duplicate", () => {
    const original = [
      { lng: 30.1, lat: -1.9 },
      { lng: 30.2, lat: -1.9 },
      { lng: 30.2, lat: -1.8 },
    ];
    const geometry = verticesToGeofenceGeometry(original);
    expect(geofenceGeometryToVertices(geometry)).toEqual(original);
  });
});
