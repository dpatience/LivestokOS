export {
  ApiClient,
  type ApiClientOptions,
} from "./client";
export {
  featureEnabled,
  GRAZING_MODE_INFO,
  PASTURE_FEATURES,
  ZERO_GRAZING_FEATURES,
  type FarmFeature,
  type PastureFeature,
  type ZeroGrazingFeature,
} from "./features";
export {
  buildPrintableQrUrl,
  formatDeviceQrPayload,
  parseDeviceQrPayload,
} from "./device-qr";
export {
  executePairDevice,
  executeUnpairDevice,
  NECKLACE_HARDWARE_TYPE,
  planPairDevice,
  planUnpairDevice,
  type PairDeviceInput,
  type PairDevicePlan,
} from "./pairing";
export {
  geofenceGeometryToVertices,
  verticesToGeofenceGeometry,
} from "./geofence-geometry";
export type {
  DiaryEntryType,
  FeedEvent,
  FeedEventPayload,
  GrazingEvent,
  GrazingEventPayload,
  HealthObservationPayload,
  InhibitorDose,
  InhibitorDosePayload,
} from "./diary";
export type {
  ChangesetErrors,
  Cow,
  CowPayload,
  Device,
  DevicePayload,
  DeviceCowSummary,
  Farm,
  FarmPayload,
  Geofence,
  GeofencePayload,
  GeofencePolygonGeometry,
  GrazingMode,
  ItemResponse,
  ListResponse,
} from "./inventory";
export { FarmResources } from "./resources";
export {
  TokenStorage,
  farmTokenStorage,
  adminTokenStorage,
  FARM_TOKEN_KEY,
  ADMIN_TOKEN_KEY,
  decodeJwtPayload,
  isTokenExpired,
} from "./auth";
export {
  ApiError,
  getRealtimeStatus,
  type AuthUser,
  type AuthResponse,
  type LoginPayload,
  type RegisterPayload,
  type JwtClaims,
  type ApiErrorBody,
  type RealtimeStatus,
} from "./types";
