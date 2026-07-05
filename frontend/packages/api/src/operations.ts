import type { ApiClient } from "./client";
import type { Alert, AlertUpdatePayload } from "./alerts";
import type {
  BreedingRecord,
  BreedingRecordPayload,
  CalvingEvent,
  CalvingEventPayload,
  DryOffSchedule,
  Gestation,
  LactationRecord,
  LactationRecordPayload,
  LactationSummary,
} from "./reproduction";
import type { ItemResponse, ListResponse } from "./inventory";

export class OperationsResources {
  constructor(private readonly client: ApiClient) {}

  listAlerts(params?: Record<string, string | number>) {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>)}` : "";
    return this.client.request<ListResponse<Alert>>(`/alerts${qs}`);
  }

  resolveAlert(id: number, payload: AlertUpdatePayload = { is_resolved: true }) {
    return this.client.request<ItemResponse<Alert>>(`/alerts/${id}`, {
      method: "PUT",
      body: JSON.stringify({ alert: payload }),
    });
  }
}

export class ReproductionResources {
  constructor(private readonly client: ApiClient) {}

  listBreedingRecords() {
    return this.client.request<ListResponse<BreedingRecord>>("/breeding_records");
  }

  createBreedingRecord(payload: BreedingRecordPayload) {
    return this.client.request<ItemResponse<BreedingRecord>>("/breeding_records", {
      method: "POST",
      body: JSON.stringify({ breeding_record: payload }),
    });
  }

  updateBreedingRecord(id: number, payload: Partial<BreedingRecordPayload>) {
    return this.client.request<ItemResponse<BreedingRecord>>(`/breeding_records/${id}`, {
      method: "PUT",
      body: JSON.stringify({ breeding_record: payload }),
    });
  }

  confirmBreeding(id: number) {
    return this.client.request<ItemResponse<Gestation>>(`/breeding_records/${id}/confirm`, {
      method: "POST",
    });
  }

  listGestations() {
    return this.client.request<ListResponse<Gestation>>("/gestations");
  }

  listLactationRecords() {
    return this.client.request<ListResponse<LactationRecord>>("/lactation_records");
  }

  createLactationRecord(payload: LactationRecordPayload) {
    return this.client.request<ItemResponse<LactationRecord>>("/lactation_records", {
      method: "POST",
      body: JSON.stringify({ lactation_record: payload }),
    });
  }

  getLactationSummary(cowId: number, from?: string, to?: string) {
    const params = new URLSearchParams({ cow_id: String(cowId) });
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    return this.client.request<ItemResponse<LactationSummary>>(
      `/lactation_records/summary?${params}`,
    );
  }

  listDryOffSchedules() {
    return this.client.request<ListResponse<DryOffSchedule>>("/dry_off_schedules");
  }

  createDryOffSchedule(gestationId: number) {
    return this.client.request<ItemResponse<DryOffSchedule>>("/dry_off_schedules", {
      method: "POST",
      body: JSON.stringify({ gestation_id: gestationId }),
    });
  }

  listCalvingEvents() {
    return this.client.request<ListResponse<CalvingEvent>>("/calving_events");
  }

  createCalvingEvent(payload: CalvingEventPayload) {
    return this.client.request<ItemResponse<CalvingEvent>>("/calving_events", {
      method: "POST",
      body: JSON.stringify({ calving_event: payload }),
    });
  }
}
