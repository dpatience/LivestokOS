import {
  geofenceGeometryToVertices,
  ndviColor,
  ndviLabel,
  verticesToGeofenceGeometry,
  type PaddockOverview,
} from "@livestok/api";
import { Button, Field, StalenessBadge, TextInput, farmCardRow } from "@livestok/ui";
import { useCallback, useState } from "react";
import { Navigate } from "react-router-dom";
import { PaddockMap } from "../components/PaddockMap";
import { formatApiError, useAuth } from "../context/AuthContext";
import { useFarmFeatures } from "../hooks/useFarmFeatures";
import { usePaddockDashboard } from "../hooks/usePaddockDashboard";

type PanelMode = "view" | "create" | "edit" | "rotate";

export function PaddockPage() {
  const { user, resources, paddocks: paddockApi } = useAuth();
  const { showGeofences } = useFarmFeatures();
  const { overview, cowLocations, loading, error, refresh } = usePaddockDashboard();

  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [panelMode, setPanelMode] = useState<PanelMode>("view");
  const [name, setName] = useState("");
  const [vertices, setVertices] = useState<{ lat: number; lng: number }[]>([]);
  const [rotateFromId, setRotateFromId] = useState<number | "">("");
  const [rotateToId, setRotateToId] = useState<number | "">("");
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState("");
  const [lastUpdated, setLastUpdated] = useState<number>(Date.now());

  const selected = overview.find((p) => p.id === selectedId) ?? null;

  const resetForm = useCallback(() => {
    setPanelMode("view");
    setName("");
    setVertices([]);
    setRotateFromId("");
    setRotateToId("");
    setActionError("");
  }, []);

  const selectPaddock = useCallback(
    (id: number) => {
      setSelectedId(id);
      const paddock = overview.find((p) => p.id === id);
      if (paddock && panelMode === "view") {
        setName(paddock.name);
      }
    },
    [overview, panelMode],
  );

  const startCreate = () => {
    resetForm();
    setPanelMode("create");
    setSelectedId(null);
  };

  const startEdit = () => {
    if (!selected) return;
    setPanelMode("edit");
    setName(selected.name);
    setVertices(geofenceGeometryToVertices(selected.geometry).map((v) => ({ lat: v.lat, lng: v.lng })));
  };

  const startRotate = () => {
    resetForm();
    setPanelMode("rotate");
    setRotateFromId(selectedId ?? "");
  };

  if (!showGeofences) {
    return <Navigate to="/" replace />;
  }

  async function handleSave() {
    if (!user?.farm_id) {
      setActionError("No farm assigned.");
      return;
    }
    if (vertices.length < 3) {
      setActionError("Draw at least 3 points on the map.");
      return;
    }
    if (!name.trim()) {
      setActionError("Enter a paddock name.");
      return;
    }

    setBusy(true);
    setActionError("");
    try {
      const geometry = verticesToGeofenceGeometry(vertices.map((v) => ({ lng: v.lng, lat: v.lat })));

      if (panelMode === "edit" && selected) {
        await resources.updateGeofence(selected.id, {
          name: name.trim(),
          geometry,
        });
      } else {
        await resources.createGeofence({
          name: name.trim(),
          enforcement_scope: "keep_in",
          geometry,
          farm_id: user.farm_id,
          is_active: true,
        });
      }

      resetForm();
      await refresh();
      setLastUpdated(Date.now());
    } catch (err) {
      setActionError(formatApiError(err));
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    if (!selected) return;
    if (!window.confirm(`Delete paddock "${selected.name}"?`)) return;

    setBusy(true);
    setActionError("");
    try {
      await resources.deleteGeofence(selected.id);
      setSelectedId(null);
      resetForm();
      await refresh();
      setLastUpdated(Date.now());
    } catch (err) {
      setActionError(formatApiError(err));
    } finally {
      setBusy(false);
    }
  }

  async function handleRotate() {
    if (!rotateFromId || !rotateToId) {
      setActionError("Select source and target paddocks.");
      return;
    }

    setBusy(true);
    setActionError("");
    try {
      const { data } = await paddockApi.rotateHerd(Number(rotateFromId), Number(rotateToId));
      resetForm();
      await refresh();
      setLastUpdated(Date.now());
      window.alert(`Rotation recorded for ${data.cows_rotated} cow(s).`);
    } catch (err) {
      setActionError(formatApiError(err));
    } finally {
      setBusy(false);
    }
  }

  const drawMode = panelMode === "create" || panelMode === "edit";

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-xl font-bold">Paddocks</h2>
          <p className="text-sm text-farm-text-muted">
            Live cow GPS, NDVI pasture health, and herd rotation on Google Maps.
          </p>
        </div>
        <StalenessBadge fetchedAt={lastUpdated} isStale={false} variant="farm" />
      </div>

      <PaddockMap
        paddocks={overview}
        cowLocations={cowLocations}
        selectedId={selectedId}
        drawMode={drawMode}
        drawVertices={vertices}
        onSelectPaddock={selectPaddock}
        onMapClick={(lat, lng) => {
          if (drawMode) setVertices((prev) => [...prev, { lat, lng }]);
        }}
      />

      {drawMode ? (
        <p className="text-sm text-farm-text-muted">
          Tap the map to add corners ({vertices.length} points). Need at least 3 for a paddock.
        </p>
      ) : (
        <p className="text-sm text-farm-text-muted">
          {cowLocations.filter((c) => c.latitude != null).length} of {cowLocations.length} cows
          with live positions · tap a paddock polygon to select
        </p>
      )}

      <div className="flex flex-wrap gap-2">
        {panelMode === "view" ? (
          <>
            <Button variant="farm" onClick={startCreate}>
              New paddock
            </Button>
            <Button variant="farm" disabled={!selected} onClick={startEdit}>
              Edit boundary
            </Button>
            <Button variant="farm" disabled={overview.length < 2} onClick={startRotate}>
              Rotate herd
            </Button>
            <Button
              variant="farm"
              className="!bg-farm-danger/10 !text-farm-danger"
              disabled={!selected || busy}
              onClick={() => void handleDelete()}
            >
              Delete
            </Button>
          </>
        ) : panelMode === "rotate" ? (
          <>
            <Button variant="farm" disabled={busy} onClick={() => void handleRotate()}>
              {busy ? "Rotating…" : "Confirm rotation"}
            </Button>
            <Button
              variant="farm"
              className="!bg-farm-surface-alt !text-farm-text border border-farm-border"
              onClick={resetForm}
            >
              Cancel
            </Button>
          </>
        ) : (
          <>
            <Button variant="farm" disabled={busy} onClick={() => void handleSave()}>
              {busy ? "Saving…" : panelMode === "edit" ? "Save changes" : "Save paddock"}
            </Button>
            <Button
              variant="farm"
              className="!bg-farm-surface-alt !text-farm-text border border-farm-border"
              onClick={() => setVertices([])}
            >
              Clear points
            </Button>
            <Button
              variant="farm"
              className="!bg-farm-surface-alt !text-farm-text border border-farm-border"
              onClick={resetForm}
            >
              Cancel
            </Button>
          </>
        )}
      </div>

      {(error || actionError) && (
        <p className="text-sm text-farm-danger" role="alert">
          {actionError || error}
        </p>
      )}

      {panelMode === "create" || panelMode === "edit" ? (
        <Field variant="farm" label="Paddock name">
          <TextInput variant="farm" value={name} onChange={(e) => setName(e.target.value)} placeholder="North paddock" />
        </Field>
      ) : null}

      {panelMode === "rotate" ? (
        <section className="space-y-3 rounded-farm border border-farm-border bg-farm-surface-alt p-3">
          <h3 className="font-semibold">Herd rotation</h3>
          <p className="text-sm text-farm-text-muted">
            Move cows with recent GPS inside the source paddock to the target paddock. Issues move
            commands and grazing alerts for each cow.
          </p>
          <Field variant="farm" label="From paddock">
            <select
              className="w-full rounded-farm border border-farm-border bg-farm-surface px-3 py-2 text-farm-text"
              value={rotateFromId}
              onChange={(e) => setRotateFromId(e.target.value ? Number(e.target.value) : "")}
            >
              <option value="">Select source…</option>
              {overview.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name} ({p.cow_count} cows)
                </option>
              ))}
            </select>
          </Field>
          <Field variant="farm" label="To paddock">
            <select
              className="w-full rounded-farm border border-farm-border bg-farm-surface px-3 py-2 text-farm-text"
              value={rotateToId}
              onChange={(e) => setRotateToId(e.target.value ? Number(e.target.value) : "")}
            >
              <option value="">Select target…</option>
              {overview.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                  {p.ndvi ? ` · NDVI ${p.ndvi.score.toFixed(2)} (${ndviLabel(p.ndvi.health)})` : ""}
                </option>
              ))}
            </select>
          </Field>
        </section>
      ) : null}

      <section>
        <h3 className="mb-2 font-semibold">Farm paddocks</h3>
        {loading && overview.length === 0 ? (
          <p className="text-farm-text-muted">Loading…</p>
        ) : overview.length === 0 ? (
          <p className="text-farm-text-muted">No paddocks yet — draw your first boundary above.</p>
        ) : (
          <ul className="space-y-2">
            {overview.map((p) => (
              <PaddockListItem
                key={p.id}
                paddock={p}
                selected={p.id === selectedId}
                onSelect={() => selectPaddock(p.id)}
              />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function PaddockListItem({
  paddock,
  selected,
  onSelect,
}: {
  paddock: PaddockOverview;
  selected: boolean;
  onSelect: () => void;
}) {
  const ndvi = paddock.ndvi;

  return (
    <li>
      <button
        type="button"
        onClick={onSelect}
        className={`${farmCardRow} w-full text-left ${selected ? "ring-2 ring-farm-primary" : ""}`}
      >
        <div className="flex items-start justify-between gap-2">
          <div>
            <p className="font-semibold">{paddock.name}</p>
            <p className="text-sm text-farm-text-muted">
              {paddock.cow_count} cow{paddock.cow_count === 1 ? "" : "s"} inside
              {paddock.last_rotation_at
                ? ` · last rotation ${new Date(paddock.last_rotation_at).toLocaleDateString()}`
                : ""}
            </p>
          </div>
          <NdviBadge paddock={paddock} />
        </div>
        {ndvi ? (
          <p className="mt-1 text-xs text-farm-text-muted">
            NDVI {ndvi.score.toFixed(2)} · {ndviLabel(ndvi.health)}
            {ndvi.is_stale ? " (stale)" : ""}
          </p>
        ) : (
          <p className="mt-1 text-xs text-farm-text-muted">No NDVI reading yet</p>
        )}
      </button>
    </li>
  );
}

function NdviBadge({ paddock }: { paddock: PaddockOverview }) {
  const health = paddock.ndvi?.health;
  const label = ndviLabel(health);

  return (
    <span
      className="shrink-0 rounded-full px-2 py-0.5 text-xs font-medium text-white"
      style={{ backgroundColor: ndviColor(health) }}
    >
      {label}
    </span>
  );
}
