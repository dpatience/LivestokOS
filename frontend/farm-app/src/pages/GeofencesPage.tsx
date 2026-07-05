import type { CacheMeta, Geofence } from "@livestok/api";
import { Button, Field, StalenessBadge, TextInput, farmCardRow } from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import { GeofenceMap, previewGeometry } from "../components/GeofenceMap";
import { formatApiError, useAuth } from "../context/AuthContext";
import { useFarmFeatures } from "../hooks/useFarmFeatures";

export function GeofencesPage() {
  const { user, resources } = useAuth();
  const { showGeofences } = useFarmFeatures();
  const [geofences, setGeofences] = useState<Geofence[]>([]);
  const [cacheMeta, setCacheMeta] = useState<CacheMeta | null>(null);
  const [name, setName] = useState("");
  const [vertices, setVertices] = useState<{ lng: number; lat: number }[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async (forceRefresh = false) => {
    setLoading(true);
    try {
      const { data, meta } = await resources.listGeofencesCached({ limit: 100 }, { forceRefresh });
      setGeofences(data);
      setCacheMeta(meta);
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [resources]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!showGeofences) {
    return <Navigate to="/" replace />;
  }

  async function handleSave() {
    if (!user?.farm_id) {
      setError("No farm assigned.");
      return;
    }
    const geometry = previewGeometry(vertices);
    if (!geometry) {
      setError("Draw at least 3 points on the map.");
      return;
    }
    if (!name.trim()) {
      setError("Enter a paddock name.");
      return;
    }

    setSaving(true);
    setError("");
    try {
      await resources.createGeofence({
        name: name.trim(),
        enforcement_scope: "keep_in",
        geometry,
        farm_id: user.farm_id,
        is_active: true,
      });
      setName("");
      setVertices([]);
      await load();
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Paddock geofences</h2>
      {cacheMeta ? (
        <StalenessBadge fetchedAt={cacheMeta.fetchedAt} isStale={cacheMeta.isStale} variant="farm" />
      ) : null}
      <p className="text-sm text-farm-text-muted">
        Draw boundaries saved as{" "}
        <code className="text-farm-text">{`{ type: "polygon", coordinates: [[lng,lat],…] }`}</code>{" "}
        per backend GeofenceEnforcer.
      </p>

      <Field variant="farm" label="Paddock name">
        <TextInput variant="farm" value={name} onChange={(e) => setName(e.target.value)} placeholder="North paddock" />
      </Field>

      <GeofenceMap vertices={vertices} onVerticesChange={setVertices} />

      <div className="flex gap-2">
        <Button variant="farm" className="flex-1" disabled={saving} onClick={() => void handleSave()}>
          {saving ? "Saving…" : "Save paddock"}
        </Button>
        <Button
          variant="farm"
          className="flex-1 !bg-farm-surface-alt !text-farm-text border border-farm-border"
          onClick={() => setVertices([])}
        >
          Clear points
        </Button>
      </div>

      {error ? (
        <p className="text-sm text-farm-danger" role="alert">
          {error}
        </p>
      ) : null}

      <section>
        <h3 className="mb-2 font-semibold">Saved paddocks</h3>
        {loading ? (
          <p className="text-farm-text-muted">Loading…</p>
        ) : geofences.length === 0 ? (
          <p className="text-farm-text-muted">No geofences yet.</p>
        ) : (
          <ul className="space-y-2">
            {geofences.map((g) => (
              <li key={g.id} className={`${farmCardRow} cursor-default hover:bg-farm-surface-alt`}>
                <p className="font-semibold">{g.name}</p>
                <p className="text-sm text-farm-text-muted">
                  {g.enforcement_scope} · {g.is_active ? "active" : "inactive"}
                </p>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
