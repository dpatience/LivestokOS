import type { AdminFarm, CacheMeta } from "@livestok/api";
import { Card, ResponsiveDataList, StalenessBadge, StatusIndicator, adminLinkInline, type DataColumn } from "@livestok/ui";
import { AlertTriangle, Wifi, WifiOff } from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAdminAuth } from "../context/AdminAuthContext";

export function DashboardPage() {
  const { admin } = useAdminAuth();
  const [farms, setFarms] = useState<AdminFarm[]>([]);
  const [cacheMeta, setCacheMeta] = useState<CacheMeta | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async (forceRefresh = false) => {
    setLoading(true);
    const { data, meta } = await admin.listFarmsCached({ forceRefresh });
    setFarms(data);
    setCacheMeta(meta);
    setLoading(false);
  }, [admin]);

  useEffect(() => {
    void load();
  }, [load]);

  const columns: DataColumn<AdminFarm>[] = [
    { id: "name", header: "Farm", mobileLabel: "Farm", cell: (f) => f.name },
    {
      id: "mode",
      header: "Mode",
      cell: (f) => <span className="capitalize">{String(f.grazing_mode).replace("_", " ")}</span>,
    },
    {
      id: "telemetry",
      header: "Devices online",
      cell: (f) => (
        <StatusIndicator
          tone={f.devices_online > 0 ? "success" : "muted"}
          icon={f.devices_online > 0 ? <Wifi size={16} /> : <WifiOff size={16} />}
          label={`${f.devices_online}/${f.devices_total}`}
        />
      ),
    },
    {
      id: "alerts",
      header: "Alerts",
      cell: (f) => (
        <StatusIndicator
          tone={f.unresolved_alerts > 0 ? "warning" : "success"}
          icon={<AlertTriangle size={16} />}
          label={String(f.unresolved_alerts)}
        />
      ),
    },
    {
      id: "location",
      header: "Location",
      cell: (f) => f.location,
    },
  ];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-xl font-bold">Cross-farm dashboard</h2>
        {cacheMeta ? (
          <StalenessBadge fetchedAt={cacheMeta.fetchedAt} isStale={cacheMeta.isStale} variant="admin" />
        ) : null}
      </div>
      <p className="text-sm text-admin-text-muted">
        Data from <code className="text-xs">GET /api/admin/farms</code> — device online counts use
        last_seen within 24h. Alert counts are live from the API response, not separately cached.
      </p>

      {loading ? <p className="text-sm">Loading farms…</p> : null}

      <ResponsiveDataList rows={farms} columns={columns} rowKey={(f) => f.id} />

      <Card variant="admin">
        <p className="text-sm text-admin-text-muted">
          Select a farm in{" "}
          <Link to="/ledger" className={adminLinkInline}>
            Ledger
          </Link>{" "}
          to audit hash-chain integrity.
        </p>
      </Card>
    </div>
  );
}
