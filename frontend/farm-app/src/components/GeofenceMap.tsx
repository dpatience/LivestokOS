import { verticesToGeofenceGeometry } from "@livestok/api";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { useEffect, useRef, useState } from "react";

export interface GeofenceMapProps {
  vertices: { lng: number; lat: number }[];
  onVerticesChange: (vertices: { lng: number; lat: number }[]) => void;
  center?: { lng: number; lat: number };
}

const OSM_STYLE: maplibregl.StyleSpecification = {
  version: 8,
  sources: {
    osm: {
      type: "raster",
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      tileSize: 256,
      attribution: "© OpenStreetMap contributors",
    },
  },
  layers: [{ id: "osm", type: "raster", source: "osm" }],
};

export function GeofenceMap({ vertices, onVerticesChange, center }: GeofenceMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const verticesRef = useRef(vertices);
  const onChangeRef = useRef(onVerticesChange);
  const [ready, setReady] = useState(false);

  verticesRef.current = vertices;
  onChangeRef.current = onVerticesChange;

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: OSM_STYLE,
      center: center ?? [30.0619, -1.9441],
      zoom: 14,
    });
    map.addControl(new maplibregl.NavigationControl(), "top-right");
    map.on("load", () => setReady(true));

    map.on("click", (e) => {
      onChangeRef.current([
        ...verticesRef.current,
        { lng: e.lngLat.lng, lat: e.lngLat.lat },
      ]);
    });

    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, [center]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;

    const sourceId = "draft-polygon";
    const fillId = "draft-polygon-fill";
    const lineId = "draft-polygon-line";
    const pointsId = "draft-points";

    const ring =
      vertices.length >= 3
        ? [...vertices.map((v) => [v.lng, v.lat]), [vertices[0].lng, vertices[0].lat]]
        : [];

    const geojson: GeoJSON.FeatureCollection = {
      type: "FeatureCollection",
      features: [
        ...(ring.length
          ? [
              {
                type: "Feature" as const,
                properties: {},
                geometry: { type: "Polygon" as const, coordinates: [ring] },
              },
            ]
          : []),
        ...vertices.map((v) => ({
          type: "Feature" as const,
          properties: {},
          geometry: { type: "Point" as const, coordinates: [v.lng, v.lat] },
        })),
      ],
    };

    if (map.getSource(sourceId)) {
      (map.getSource(sourceId) as maplibregl.GeoJSONSource).setData(geojson);
    } else {
      map.addSource(sourceId, { type: "geojson", data: geojson });
      map.addLayer({
        id: fillId,
        type: "fill",
        source: sourceId,
        filter: ["==", "$type", "Polygon"],
        paint: { "fill-color": "#0B5E2E", "fill-opacity": 0.25 },
      });
      map.addLayer({
        id: lineId,
        type: "line",
        source: sourceId,
        filter: ["==", "$type", "Polygon"],
        paint: { "line-color": "#0B5E2E", "line-width": 3 },
      });
      map.addLayer({
        id: pointsId,
        type: "circle",
        source: sourceId,
        filter: ["==", "$type", "Point"],
        paint: { "circle-radius": 8, "circle-color": "#D97706", "circle-stroke-width": 2, "circle-stroke-color": "#fff" },
      });
    }
  }, [vertices, ready]);

  return (
    <div className="space-y-2">
      <div ref={containerRef} className="h-72 w-full overflow-hidden rounded-farm border border-farm-border" />
      <p className="text-sm text-farm-text-muted">
        Tap the map to add corners ({vertices.length} points). Need at least 3 for a paddock.
      </p>
    </div>
  );
}

export function previewGeometry(vertices: { lng: number; lat: number }[]) {
  try {
    return verticesToGeofenceGeometry(vertices);
  } catch {
    return null;
  }
}
