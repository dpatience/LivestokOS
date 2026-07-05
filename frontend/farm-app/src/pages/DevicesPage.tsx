import type { Device } from "@livestok/api";
import { executeUnpairDevice } from "@livestok/api";
import { Button, Card, farmChip, farmInteractive, farmLinkInline, farmLinkPrimary, farmLinkSecondary } from "@livestok/ui";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { formatApiError, useAuth } from "../context/AuthContext";

export function DevicesPage() {
  const { resources } = useAuth();
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState<"all" | "paired" | "unpaired">("all");
  const [busyId, setBusyId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await resources.listDevices({ limit: 200 });
      setDevices(data);
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [resources]);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = useMemo(() => {
    if (filter === "paired") return devices.filter((d) => d.cow !== null);
    if (filter === "unpaired") return devices.filter((d) => d.cow === null);
    return devices;
  }, [devices, filter]);

  async function handleUnpair(device: Device) {
    if (
      !confirm(
        `Unpair ${device.serial} from ${device.cow?.name ?? "cow"}? The necklace stays registered but won't be linked.`,
      )
    ) {
      return;
    }
    setBusyId(device.id);
    setError("");
    try {
      await executeUnpairDevice(resources, device.id);
      await load();
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h2 className="text-xl font-bold">Necklace devices</h2>
        <Link to="/devices/pair" className={farmLinkPrimary}>
          + Pair
        </Link>
      </div>

      <p className="text-sm text-farm-text-muted">
        Pair via QR scan (all phones) or NFC (Chrome on Android only). Re-pair moves a necklace
        to another cow; unpair clears the cow link without deleting the device record.
      </p>

      <div className="flex gap-2">
        {(["all", "paired", "unpaired"] as const).map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => setFilter(f)}
            className={`${farmChip} flex-1 ${
              filter === f
                ? "border-farm-primary bg-farm-primary/10 text-farm-primary"
                : "border-farm-border text-farm-text-muted hover:border-farm-primary/40"
            }`}
          >
            {f === "all" ? "All" : f === "paired" ? "Paired" : "Unpaired"}
          </button>
        ))}
      </div>

      {error ? (
        <p className="text-sm text-farm-danger" role="alert">
          {error}
        </p>
      ) : null}

      {loading ? (
        <p className="text-farm-text-muted">Loading devices…</p>
      ) : filtered.length === 0 ? (
        <Card variant="farm">
          <p className="text-farm-text-muted">No devices found.</p>
          <Link to="/devices/pair" className={`mt-3 inline-block ${farmLinkInline}`}>
            Pair your first necklace
          </Link>
        </Card>
      ) : (
        <ul className="space-y-2">
          {filtered.map((device) => (
            <DeviceRow
              key={device.id}
              device={device}
              busy={busyId === device.id}
              onUnpair={() => void handleUnpair(device)}
            />
          ))}
        </ul>
      )}

      <Button
        variant="farm"
        className="w-full !bg-farm-surface-alt !text-farm-text border border-farm-border"
        onClick={() => void load()}
      >
        Refresh
      </Button>
    </div>
  );
}

function DeviceRow({
  device,
  busy,
  onUnpair,
}: {
  device: Device;
  busy: boolean;
  onUnpair: () => void;
}) {
  const paired = device.cow !== null;
  return (
    <li className={`rounded-farm border border-farm-border bg-farm-surface-alt px-4 py-3 transition-colors hover:border-farm-primary/40 hover:bg-white`}>
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold text-farm-text">{device.serial}</p>
          <p className="text-sm text-farm-text-muted">
            {device.hardware_type} · {device.status}
          </p>
          {paired ? (
            <p className="text-sm text-farm-success">
              Paired to {device.cow!.name} ({device.cow!.tag_id})
            </p>
          ) : (
            <p className="text-sm text-farm-accent">Unpaired</p>
          )}
          <div className="mt-2 flex flex-wrap gap-2">
            {paired ? (
              <>
                <Link
                  to={`/devices/${device.id}/repair`}
                  className={`${farmLinkSecondary} !min-h-10 !px-3 text-sm !text-farm-primary`}
                >
                  Re-pair
                </Link>
                <button
                  type="button"
                  disabled={busy}
                  className={`${farmInteractive} tap-target inline-flex items-center rounded-farm border border-farm-danger px-3 text-sm font-semibold text-farm-danger hover:bg-farm-danger/5 focus-visible:ring-farm-danger disabled:opacity-50`}
                  onClick={onUnpair}
                >
                  {busy ? "…" : "Unpair"}
                </button>
              </>
            ) : (
              <Link
                to={`/devices/pair?serial=${encodeURIComponent(device.serial)}`}
                className={`${farmLinkPrimary} !min-h-10 !px-3 text-sm`}
              >
                Pair to cow
              </Link>
            )}
          </div>
        </div>
        <span
          className={`shrink-0 rounded-full px-2 py-1 text-xs font-bold ${
            paired ? "bg-farm-success/15 text-farm-success" : "bg-farm-accent/15 text-farm-accent"
          }`}
        >
          {paired ? "Paired" : "Unpaired"}
        </span>
      </div>
    </li>
  );
}
