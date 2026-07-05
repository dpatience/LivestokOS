import { featureEnabled } from "@livestok/api";
import { useAuth } from "../context/AuthContext";

export function useFarmFeatures() {
  const { farm } = useAuth();
  const mode = farm?.grazing_mode ?? "pasture";

  return {
    mode,
    showGeofences: featureEnabled(mode, "virtual_fence_rotation"),
    showSatellite: featureEnabled(mode, "satellite_ndvi"),
    showGrazingCoach: featureEnabled(mode, "grazing_coach"),
    showZeroGrazing: featureEnabled(mode, "rfid_inhibitor_dosing"),
  };
}
