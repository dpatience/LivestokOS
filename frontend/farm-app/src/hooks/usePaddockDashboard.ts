import type { CowLocation, PaddockOverview } from "@livestok/api";
import { useCallback, useEffect, useState } from "react";
import { formatApiError, useAuth } from "../context/AuthContext";

const POLL_MS = 15_000;

export function usePaddockDashboard() {
  const { paddocks: paddockApi } = useAuth();
  const [overview, setOverview] = useState<PaddockOverview[]>([]);
  const [cowLocations, setCowLocations] = useState<CowLocation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const refresh = useCallback(async () => {
    try {
      const [overviewRes, locationsRes] = await Promise.all([
        paddockApi.getOverview(),
        paddockApi.getCowLocations(),
      ]);
      setOverview(overviewRes.data);
      setCowLocations(locationsRes.data);
      setError("");
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [paddockApi]);

  useEffect(() => {
    void refresh();
    const id = window.setInterval(() => void refresh(), POLL_MS);
    return () => window.clearInterval(id);
  }, [refresh]);

  return { overview, cowLocations, loading, error, refresh };
}
