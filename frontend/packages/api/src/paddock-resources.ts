import type { ApiClient } from "./client";
import type { ItemResponse, ListResponse } from "./inventory";
import type { CowLocation, PaddockOverview, RotationResult } from "./paddock";

export class PaddockResources {
  constructor(private readonly client: ApiClient) {}

  getOverview() {
    return this.client.request<ListResponse<PaddockOverview>>("/paddocks/overview");
  }

  getCowLocations() {
    return this.client.request<ListResponse<CowLocation>>("/cows/locations");
  }

  rotateHerd(fromPaddockId: number, targetPaddockId: number) {
    return this.client.request<ItemResponse<RotationResult>>(`/paddocks/${fromPaddockId}/rotate`, {
      method: "POST",
      body: JSON.stringify({ rotation: { target_paddock_id: targetPaddockId } }),
    });
  }
}
