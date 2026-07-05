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
export type { CacheMeta, CachedListResponse } from "./resources";
export { clearResponseCache } from "./response-cache";
export { FarmResources } from "./resources";
export { OperationsResources, ReproductionResources } from "./operations";
export { ConsultResources } from "./consult-resources";
export { PaddockResources } from "./paddock-resources";
export { AdminResources } from "./admin-resources";
export {
  isSuperAdmin,
  type AdminDevice,
  type AdminDeviceCow,
  type AdminFarm,
  type ConfirmedCaseRecord,
  type DigitalPassport,
  type FarmLedger,
  type IngestionJobState,
  type IngestionJobStatus,
  type IngestionStatus,
  type LedgerChainStatus,
  type LedgerEntry,
  type ResearchArticleRecord,
  type RevokeCaseResult,
  type TriggerIngestionResult,
  type UserRole,
} from "./admin";
export {
  formatConfirmedDate,
  isConfirmedCaseReply,
  isInsufficientReply,
  sourceLabel,
  SOURCE_LABELS,
  type ConsultAttribution,
  type ConsultHistoryEntry,
  type ConsultReply,
  type ConsultSession,
  type ConsultSource,
  type ConsultSourceType,
  type ConfirmedCaseRef,
} from "./consult";
export {
  alertDomain,
  alertVisualGroup,
  effectiveSeverityScore,
  filterGrazingCoachAlerts,
  filterUrgentAlerts,
  isGrazingCoachAlert,
  isHighSeverityAlert,
  sortAlertsBySeverity,
  type Alert,
  type AlertDomain,
  type AlertUpdatePayload,
  type AlertVisualGroup,
} from "./alerts";
export type {
  BreedingMethod,
  BreedingOutcome,
  BreedingRecord,
  BreedingRecordPayload,
  CalvingDifficulty,
  CalvingEvent,
  CalvingEventPayload,
  DryOffSchedule,
  DryOffStatus,
  Gestation,
  GestationStatus,
  LactationRecord,
  LactationRecordPayload,
  LactationSummary,
} from "./reproduction";
export {
  ndviColor,
  ndviLabel,
  NDVI_HEALTH_COLORS,
  NDVI_HEALTH_LABELS,
  type CowLocation,
  type NdviHealth,
  type PaddockNdvi,
  type PaddockOverview,
  type RotationResult,
} from "./paddock";
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
