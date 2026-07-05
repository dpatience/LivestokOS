import { Card } from "@livestok/ui";
import { Link } from "react-router-dom";
import { GrazingModeBadge } from "../components/GrazingModePicker";
import { useAuth } from "../context/AuthContext";
import { useFarmFeatures } from "../hooks/useFarmFeatures";

export function HomePage() {
  const { farm } = useAuth();
  const { showGeofences, showZeroGrazing } = useFarmFeatures();

  if (!farm) {
    return (
      <Card variant="farm">
        <p className="text-farm-text-muted">No farm linked to your account.</p>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <GrazingModeBadge mode={farm.grazing_mode} />

      <Card variant="farm">
        <p className="text-sm text-farm-text-muted">Location</p>
        <p className="text-farm-body font-semibold">{farm.location}</p>
      </Card>

      <div className="grid gap-3">
        <Link
          to="/herd"
          className="tap-target flex w-full flex-col items-center justify-center rounded-farm bg-farm-primary py-4 text-farm-body font-semibold text-white"
        >
          <span className="text-2xl" aria-hidden>
            🐄
          </span>
          Manage herd
        </Link>

        {showGeofences ? (
          <Link
            to="/geofences"
            className="tap-target flex w-full flex-col items-center justify-center rounded-farm bg-farm-accent py-4 text-farm-body font-semibold text-white"
          >
            <span className="text-2xl" aria-hidden>
              🗺️
            </span>
            Draw paddock boundaries
          </Link>
        ) : null}

        <Link
          to="/devices"
          className="tap-target flex w-full flex-col items-center justify-center rounded-farm border border-farm-border bg-farm-surface-alt py-4 text-farm-body font-semibold text-farm-text"
        >
          <span className="text-2xl" aria-hidden>
            📡
          </span>
          Necklace devices
        </Link>
      </div>

      {showZeroGrazing ? (
        <p className="text-sm text-farm-text-muted">
          Indoor modules (RFID dosing, feed robot, BMS) will appear in later stages for your
          zero-grazing / mixed setup.
        </p>
      ) : null}
    </div>
  );
}
