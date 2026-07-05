import type { GeofencePolygonGeometry } from "./inventory";

/**
 * Convert MapLibre lngLat vertices to backend polygon geometry.
 * Backend expects closed ring of [lng, lat] pairs (GeofenceEnforcerTest).
 */
export function verticesToGeofenceGeometry(
  vertices: { lng: number; lat: number }[],
): GeofencePolygonGeometry {
  if (vertices.length < 3) {
    throw new Error("A paddock needs at least 3 points");
  }

  const coordinates: [number, number][] = vertices.map((v) => [
    roundCoord(v.lng),
    roundCoord(v.lat),
  ]);

  const first = coordinates[0];
  const last = coordinates[coordinates.length - 1];
  if (first[0] !== last[0] || first[1] !== last[1]) {
    coordinates.push([...first]);
  }

  return { type: "polygon", coordinates };
}

export function geofenceGeometryToVertices(
  geometry: GeofencePolygonGeometry | Record<string, unknown>,
): { lng: number; lat: number }[] {
  if (geometry.type !== "polygon" || !Array.isArray(geometry.coordinates)) {
    return [];
  }
  const coords = geometry.coordinates as [number, number][];
  if (coords.length < 2) return [];
  const first = coords[0];
  const last = coords[coords.length - 1];
  const closed =
    first[0] === last[0] && first[1] === last[1]
      ? coords.slice(0, -1)
      : coords;
  return closed.map(([lng, lat]) => ({ lng, lat }));
}

function roundCoord(n: number): number {
  return Math.round(n * 1e6) / 1e6;
}
