import { isHighSeverityAlert, type Alert } from "@livestok/api";
import { useCallback, useEffect, useRef, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { showAlertViaServiceWorker } from "../lib/push-notifications";

export function useAlerts(pollMs = 60_000) {
  const { operations } = useAuth();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);
  const notifiedRef = useRef<Set<number>>(new Set());

  const refresh = useCallback(async () => {
    const { data } = await operations.listAlerts({ limit: 100 });
    setAlerts(data);

    if (typeof Notification !== "undefined" && Notification.permission === "granted") {
      for (const alert of data) {
        if (isHighSeverityAlert(alert) && !notifiedRef.current.has(alert.id)) {
          notifiedRef.current.add(alert.id);
          void showAlertViaServiceWorker(alert);
        }
      }
    }
    setLoading(false);
  }, [operations]);

  const resolve = useCallback(
    async (id: number) => {
      await operations.resolveAlert(id);
      setAlerts((prev) => prev.filter((a) => a.id !== id));
    },
    [operations],
  );

  useEffect(() => {
    void refresh();
    const id = setInterval(() => void refresh(), pollMs);
    return () => clearInterval(id);
  }, [refresh, pollMs]);

  return { alerts, loading, refresh, resolve };
}
