import type { ApiClient } from "./client";
import type {
  ChangesetErrors,
  Cow,
  CowPayload,
  Device,
  DevicePayload,
  Farm,
  FarmPayload,
  Geofence,
  GeofencePayload,
  ItemResponse,
  ListResponse,
} from "./inventory";
import type {
  FeedEvent,
  FeedEventPayload,
  GrazingEvent,
  GrazingEventPayload,
  InhibitorDose,
  InhibitorDosePayload,
} from "./diary";

function wrapCow(payload: CowPayload) {
  return { cow: payload };
}

function wrapFarm(payload: FarmPayload) {
  return { farm: payload };
}

function wrapGeofence(payload: GeofencePayload) {
  return { geofence: payload };
}

function wrapDevice(payload: DevicePayload | Partial<DevicePayload>) {
  return { device: payload };
}

export class FarmResources {
  constructor(private readonly client: ApiClient) {}

  listFarms(params?: Record<string, string | number>) {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>)}` : "";
    return this.client.request<ListResponse<Farm>>(`/farms${qs}`);
  }

  getFarm(id: number) {
    return this.client.request<ItemResponse<Farm>>(`/farms/${id}`);
  }

  createFarm(payload: FarmPayload) {
    return this.client.request<ItemResponse<Farm>>("/farms", {
      method: "POST",
      body: JSON.stringify(wrapFarm(payload)),
    });
  }

  updateFarm(id: number, payload: Partial<FarmPayload>) {
    return this.client.request<ItemResponse<Farm>>(`/farms/${id}`, {
      method: "PUT",
      body: JSON.stringify(wrapFarm(payload as FarmPayload)),
    });
  }

  deleteFarm(id: number) {
    return this.client.request<void>(`/farms/${id}`, { method: "DELETE" });
  }

  listCows(params?: Record<string, string | number>) {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>)}` : "";
    return this.client.request<ListResponse<Cow>>(`/cows${qs}`);
  }

  getCow(id: number) {
    return this.client.request<ItemResponse<Cow>>(`/cows/${id}`);
  }

  createCow(payload: CowPayload) {
    return this.client.request<ItemResponse<Cow>>("/cows", {
      method: "POST",
      body: JSON.stringify(wrapCow(payload)),
    });
  }

  updateCow(id: number, payload: Partial<CowPayload>) {
    return this.client.request<ItemResponse<Cow>>(`/cows/${id}`, {
      method: "PUT",
      body: JSON.stringify(wrapCow(payload as CowPayload)),
    });
  }

  deleteCow(id: number) {
    return this.client.request<void>(`/cows/${id}`, { method: "DELETE" });
  }

  listGeofences(params?: Record<string, string | number>) {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>)}` : "";
    return this.client.request<ListResponse<Geofence>>(`/geofences${qs}`);
  }

  createGeofence(payload: GeofencePayload) {
    return this.client.request<ItemResponse<Geofence>>("/geofences", {
      method: "POST",
      body: JSON.stringify(wrapGeofence(payload)),
    });
  }

  deleteGeofence(id: number) {
    return this.client.request<void>(`/geofences/${id}`, { method: "DELETE" });
  }

  listDevices(params?: Record<string, string | number>) {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>)}` : "";
    return this.client.request<ListResponse<Device>>(`/devices${qs}`);
  }

  getDevice(id: number) {
    return this.client.request<ItemResponse<Device>>(`/devices/${id}`);
  }

  createDevice(payload: DevicePayload) {
    return this.client.request<ItemResponse<Device>>("/devices", {
      method: "POST",
      body: JSON.stringify(wrapDevice(payload)),
    });
  }

  updateDevice(id: number, payload: Partial<DevicePayload>) {
    return this.client.request<ItemResponse<Device>>(`/devices/${id}`, {
      method: "PUT",
      body: JSON.stringify(wrapDevice(payload)),
    });
  }

  deleteDevice(id: number) {
    return this.client.request<void>(`/devices/${id}`, { method: "DELETE" });
  }

  createFeedEvent(payload: FeedEventPayload) {
    return this.client.request<ItemResponse<FeedEvent>>("/feed_events", {
      method: "POST",
      body: JSON.stringify({ feed_event: payload }),
    });
  }

  createInhibitorDose(payload: InhibitorDosePayload) {
    return this.client.request<ItemResponse<InhibitorDose>>("/inhibitor_doses", {
      method: "POST",
      body: JSON.stringify({ inhibitor_dose: payload }),
    });
  }

  createGrazingEvent(payload: GrazingEventPayload) {
    return this.client.request<ItemResponse<GrazingEvent>>("/grazing_events", {
      method: "POST",
      body: JSON.stringify({ grazing_event: payload }),
    });
  }
}

export type { ChangesetErrors };
