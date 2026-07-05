import { featureEnabled } from "@livestok/api";
import { useAuth } from "../context/AuthContext";

/**
 * Grazing Coach visibility derived from GET /api/farms/:id `grazing_mode`,
 * using the same rules as backend Inventory.feature_enabled?(:grazing_coach).
 * Returns false until farm is loaded; entirely absent for zero_grazing.
 */
export function useGrazingCoachVisible(): boolean {
  const { farm } = useAuth();
  if (!farm) return false;
  return featureEnabled(farm.grazing_mode, "grazing_coach");
}
