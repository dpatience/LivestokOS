import type { ApiClient } from "./client";
import type {
  AdminDevice,
  AdminFarm,
  ConfirmedCaseRecord,
  DigitalPassport,
  FarmLedger,
  IngestionStatus,
  ResearchArticleRecord,
  RevokeCaseResult,
  TriggerIngestionResult,
} from "./admin";
import type { ItemResponse, ListResponse } from "./inventory";
import { fetchWithCache, type CacheMeta } from "./response-cache";

export type { CacheMeta };

const ADMIN_FARMS_CACHE_TTL_MS = 5 * 60 * 1000;

export interface CachedListResponse<T> {
  data: T[];
  meta: CacheMeta;
}

export class AdminResources {
  constructor(private readonly client: ApiClient) {}

  listFarms() {
    return this.client.request<ListResponse<AdminFarm>>("/admin/farms");
  }

  async listFarmsCached(options?: { forceRefresh?: boolean }): Promise<CachedListResponse<AdminFarm>> {
    const result = await fetchWithCache(
      "admin:farms",
      async () => {
        const res = await this.listFarms();
        return res.data;
      },
      { ttlMs: ADMIN_FARMS_CACHE_TTL_MS, forceRefresh: options?.forceRefresh },
    );
    return { data: result.data, meta: result.meta };
  }

  listDevices(params?: { limit?: number }) {
    const qs = params?.limit ? `?limit=${params.limit}` : "";
    return this.client.request<ListResponse<AdminDevice>>(`/admin/devices${qs}`);
  }

  getFarmLedger(farmId: number) {
    return this.client.request<ItemResponse<FarmLedger>>(`/admin/farms/${farmId}/ledger`);
  }

  getDigitalPassport(farmId: number, cowId: number) {
    return this.client.request<ItemResponse<DigitalPassport>>(
      `/farms/${farmId}/cows/${cowId}/digital_passport`,
    );
  }

  listConfirmedCases(params?: { limit?: number; farm_id?: number }) {
    const search = new URLSearchParams();
    if (params?.limit) search.set("limit", String(params.limit));
    if (params?.farm_id) search.set("farm_id", String(params.farm_id));
    const qs = search.toString();
    return this.client.request<ListResponse<ConfirmedCaseRecord>>(
      `/admin/ai/confirmed_cases${qs ? `?${qs}` : ""}`,
    );
  }

  revokeConfirmedCase(caseId: number) {
    return this.client.request<ItemResponse<RevokeCaseResult>>(
      `/admin/ai/confirmed_cases/${caseId}/revoke`,
      { method: "POST" },
    );
  }

  listResearchArticles(params?: { limit?: number }) {
    const qs = params?.limit ? `?limit=${params.limit}` : "";
    return this.client.request<ListResponse<ResearchArticleRecord>>(
      `/admin/ai/research_articles${qs}`,
    );
  }

  getIngestionStatus() {
    return this.client.request<ItemResponse<IngestionStatus>>("/admin/ai/research/ingestion_status");
  }

  triggerIngestion() {
    return this.client.request<ItemResponse<TriggerIngestionResult>>(
      "/admin/ai/research/trigger_ingestion",
      { method: "POST" },
    );
  }
}
