import type { GrazingMode } from "./inventory";

export const PASTURE_FEATURES = [
  "satellite_ndvi",
  "virtual_fence_rotation",
  "grazing_coach",
] as const;

export const ZERO_GRAZING_FEATURES = [
  "rfid_inhibitor_dosing",
  "feed_robot_integration",
  "bms_climate_control",
] as const;

export type PastureFeature = (typeof PASTURE_FEATURES)[number];
export type ZeroGrazingFeature = (typeof ZERO_GRAZING_FEATURES)[number];
export type FarmFeature = PastureFeature | ZeroGrazingFeature;

/**
 * Mirrors LivestokOs.Inventory.feature_enabled?/2 rules.
 */
export function featureEnabled(
  mode: GrazingMode,
  feature: FarmFeature,
): boolean {
  if ((PASTURE_FEATURES as readonly string[]).includes(feature)) {
    return mode === "pasture" || mode === "mixed";
  }
  if ((ZERO_GRAZING_FEATURES as readonly string[]).includes(feature)) {
    return mode === "zero_grazing" || mode === "mixed";
  }
  return false;
}

export const GRAZING_MODE_INFO: Record<
  GrazingMode,
  { title: string; description: string; features: string[] }
> = {
  pasture: {
    title: "Pasture grazing",
    description:
      "Cattle graze outdoors on paddocks. Enables satellite NDVI, virtual fence rotation, and grazing coach.",
    features: ["Satellite NDVI", "Virtual fences", "Grazing coach"],
  },
  zero_grazing: {
    title: "Zero grazing (indoor)",
    description:
      "Cattle housed indoors with cut-and-carry feed. Enables RFID inhibitor dosing, feed integration, and BMS climate.",
    features: ["RFID inhibitor dosing", "Feed robot integration", "BMS climate"],
  },
  mixed: {
    title: "Mixed system",
    description:
      "Both pasture and indoor workflows. All feature modules are available — use what fits each season.",
    features: ["All pasture + indoor features"],
  },
};
