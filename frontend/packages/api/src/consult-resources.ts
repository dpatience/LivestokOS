import type { ApiClient } from "./client";
import type {
  ConsultHistoryEntry,
  ConsultReply,
  ConsultSession,
} from "./consult";
import type { ItemResponse, ListResponse } from "./inventory";

export class ConsultResources {
  constructor(private readonly client: ApiClient) {}

  /** Requires cow_id — session is scoped to one cow per backend ConsultSession.start_session/3 */
  startSession(cowId: number) {
    return this.client.request<ItemResponse<ConsultSession>>("/consult/sessions", {
      method: "POST",
      body: JSON.stringify({ consult: { cow_id: cowId } }),
    });
  }

  /** Non-streaming: full JSON response returned when complete (no SSE). */
  sendMessage(sessionId: string, content: string) {
    return this.client.request<ItemResponse<ConsultReply>>(
      `/consult/sessions/${sessionId}/messages`,
      {
        method: "POST",
        body: JSON.stringify({ message: { content } }),
      },
    );
  }

  getHistory(sessionId: string) {
    return this.client.request<ListResponse<ConsultHistoryEntry>>(
      `/consult/sessions/${sessionId}/history`,
    );
  }
}
