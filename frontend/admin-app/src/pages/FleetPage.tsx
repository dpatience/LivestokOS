import type { AdminDevice } from "@livestok/api";
import {
  ResponsiveDataList,
  StatusIndicator,
  type DataColumn,
} from "@livestok/ui";
import { Battery, BatteryLow, BatteryMedium, Link2, Wifi, WifiOff } from "@livestok/ui";
import { useEffect, useState } from "react";
import { useAdminAuth } from "../context/AdminAuthContext";

function batteryIcon(level: number | null) {
  if (level == null) return <Battery size={16} />;
  if (level < 25) return <BatteryLow size={16} />;
  if (level < 60) return <BatteryMedium size={16} />;
  return <Battery size={16} />;
}

function batteryTone(level: number | null): "success" | "warning" | "danger" | "muted" {
  if (level == null) return "muted";
  if (level < 25) return "danger";
  if (level < 60) return "warning";
  return "success";
}

function isOnline(lastSeen: string | null): boolean {
  if (!lastSeen) return false;
  const hours = (Date.now() - new Date(lastSeen).getTime()) / 3_600_000;
  return hours <= 24;
}

export function FleetPage() {
  const { admin } = useAdminAuth();
  const [devices, setDevices] = useState<AdminDevice[]>([]);

  useEffect(() => {
    void (async () => {
      const { data } = await admin.listDevices({ limit: 500 });
      setDevices(data);
    })();
  }, [admin]);

  const columns: DataColumn<AdminDevice>[] = [
    { id: "serial", header: "Serial", cell: (d) => d.serial },
    { id: "farm", header: "Farm", cell: (d) => d.farm_name ?? "—" },
    {
      id: "online",
      header: "Status",
      cell: (d) => (
        <StatusIndicator
          tone={isOnline(d.last_seen_at) ? "success" : "muted"}
          icon={isOnline(d.last_seen_at) ? <Wifi size={16} /> : <WifiOff size={16} />}
          label={isOnline(d.last_seen_at) ? "Online" : "Offline"}
        />
      ),
    },
    {
      id: "battery",
      header: "Battery",
      cell: (d) => (
        <StatusIndicator
          tone={batteryTone(d.battery_level)}
          icon={batteryIcon(d.battery_level)}
          label={d.battery_level != null ? `${Math.round(d.battery_level)}%` : "N/A"}
        />
      ),
    },
    {
      id: "paired",
      header: "Pairing",
      cell: (d) => (
        <StatusIndicator
          tone={d.paired ? "success" : "warning"}
          icon={<Link2 size={16} />}
          label={d.paired ? (d.cow?.name ?? "Paired") : "Unpaired"}
        />
      ),
    },
    {
      id: "seen",
      header: "Last seen",
      cell: (d) => (d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : "Never"),
    },
  ];

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Necklace fleet</h2>
      <p className="text-sm text-admin-text-muted">
        From <code className="text-xs">GET /api/admin/devices</code> — battery from latest sensor
        reading per device.
      </p>
      <ResponsiveDataList rows={devices} columns={columns} rowKey={(d) => d.id} emptyMessage="No devices registered." />
    </div>
  );
}
