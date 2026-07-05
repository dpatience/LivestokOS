import {
  geofenceGeometryToVertices,
  ndviColor,
  type CowLocation,
  type PaddockOverview,
} from "@livestok/api";
import { APIProvider, Map, Marker, Polygon, useMap } from "@vis.gl/react-google-maps";
import { useEffect } from "react";

const DEFAULT_CENTER = { lat: -1.9441, lng: 30.0619 };

export interface PaddockMapProps {
  paddocks: PaddockOverview[];
  cowLocations: CowLocation[];
  selectedId: number | null;
  drawVertices: { lat: number; lng: number }[];
  drawMode: boolean;
  onMapClick?: (lat: number, lng: number) => void;
  onSelectPaddock?: (id: number) => void;
}

function FitBounds({ paddocks, cows }: { paddocks: PaddockOverview[]; cows: CowLocation[] }) {
  const map = useMap();

  useEffect(() => {
    if (!map || typeof google === "undefined") return;

    const bounds = new google.maps.LatLngBounds();
    let hasPoint = false;

    for (const p of paddocks) {
      for (const v of geofenceGeometryToVertices(p.geometry)) {
        bounds.extend({ lat: v.lat, lng: v.lng });
        hasPoint = true;
      }
    }

    for (const c of cows) {
      if (c.latitude != null && c.longitude != null) {
        bounds.extend({ lat: c.latitude, lng: c.longitude });
        hasPoint = true;
      }
    }

    if (hasPoint) {
      map.fitBounds(bounds, 48);
    }
  }, [map, paddocks, cows]);

  return null;
}

function MapClickHandler({ drawMode, onMapClick }: { drawMode: boolean; onMapClick?: (lat: number, lng: number) => void }) {
  const map = useMap();

  useEffect(() => {
    if (!map || !drawMode || !onMapClick) return;

    const listener = map.addListener("click", (e: google.maps.MapMouseEvent) => {
      if (e.latLng) {
        onMapClick(e.latLng.lat(), e.latLng.lng());
      }
    });

    return () => listener.remove();
  }, [map, drawMode, onMapClick]);

  return null;
}

function PaddockPolygons({
  paddocks,
  selectedId,
  onSelectPaddock,
}: {
  paddocks: PaddockOverview[];
  selectedId: number | null;
  onSelectPaddock?: (id: number) => void;
}) {
  return (
    <>
      {paddocks.map((paddock) => {
        const paths = geofenceGeometryToVertices(paddock.geometry).map((v) => ({ lat: v.lat, lng: v.lng }));
        if (paths.length < 3) return null;

        const fill = ndviColor(paddock.ndvi?.health);
        const selected = paddock.id === selectedId;

        return (
          <Polygon
            key={paddock.id}
            paths={paths}
            fillColor={fill}
            fillOpacity={selected ? 0.45 : 0.28}
            strokeColor={selected ? "#0B5E2E" : fill}
            strokeWeight={selected ? 3 : 2}
            onClick={() => onSelectPaddock?.(paddock.id)}
          />
        );
      })}
    </>
  );
}

function DraftPolygon({ vertices }: { vertices: { lat: number; lng: number }[] }) {
  if (vertices.length < 2) {
    return (
      <>
        {vertices.map((v, i) => (
          <Marker key={`draft-${i}`} position={v} label={`${i + 1}`} />
        ))}
      </>
    );
  }

  return (
    <>
      <Polygon
        paths={vertices}
        fillColor="#D97706"
        fillOpacity={vertices.length >= 3 ? 0.2 : 0}
        strokeColor="#D97706"
        strokeWeight={2}
      />
      {vertices.map((v, i) => (
        <Marker key={`draft-${i}`} position={v} label={`${i + 1}`} />
      ))}
    </>
  );
}

function CowMarkers({ cows }: { cows: CowLocation[] }) {
  return (
    <>
      {cows
        .filter((c) => c.latitude != null && c.longitude != null)
        .map((cow) => (
          <Marker
            key={cow.cow_id}
            position={{ lat: cow.latitude!, lng: cow.longitude! }}
            title={`${cow.name} (${cow.status})`}
            label={cow.name.slice(0, 1).toUpperCase()}
          />
        ))}
    </>
  );
}

function PaddockMapInner(props: PaddockMapProps) {
  return (
    <Map
      defaultCenter={DEFAULT_CENTER}
      defaultZoom={14}
      gestureHandling="greedy"
      disableDefaultUI={false}
      className="h-full w-full"
    >
      <FitBounds paddocks={props.paddocks} cows={props.cowLocations} />
      <MapClickHandler drawMode={props.drawMode} onMapClick={props.onMapClick} />
      <PaddockPolygons
        paddocks={props.paddocks}
        selectedId={props.selectedId}
        onSelectPaddock={props.onSelectPaddock}
      />
      <CowMarkers cows={props.cowLocations} />
      {props.drawMode ? <DraftPolygon vertices={props.drawVertices} /> : null}
    </Map>
  );
}

export function PaddockMap(props: PaddockMapProps) {
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

  if (!apiKey) {
    return (
      <div className="flex h-80 items-center justify-center rounded-farm border border-farm-border bg-farm-surface-alt p-4 text-center text-sm text-farm-text-muted">
        Set <code className="text-farm-text">VITE_GOOGLE_MAPS_API_KEY</code> in your farm-app{" "}
        <code className="text-farm-text">.env</code> to show the paddock map.
      </div>
    );
  }

  return (
    <div className="h-80 w-full overflow-hidden rounded-farm border border-farm-border">
      <APIProvider apiKey={apiKey}>
        <PaddockMapInner {...props} />
      </APIProvider>
    </div>
  );
}
