import type {
  DiaryEntryType,
  FarmResources,
  FeedEventPayload,
  GrazingEventPayload,
  HealthObservationPayload,
  InhibitorDosePayload,
} from "@livestok/api";
import type { OutboxEntry } from "../db/outbox";
import {
  enqueueOutbox,
  listPendingOutbox,
  updateOutboxEntry,
} from "../db/outbox";

export interface DiarySubmission {
  entryType: DiaryEntryType;
  cowId: number;
  cowName: string;
  farmId?: number;
  payload:
    | FeedEventPayload
    | InhibitorDosePayload
    | GrazingEventPayload
    | HealthObservationPayload;
}

export interface SubmitDiaryOptions {
  resources: FarmResources;
  online?: boolean;
}

export interface SubmitDiaryResult {
  mode: "synced" | "queued";
  outboxId?: string;
}

function routeSubmission(submission: DiarySubmission): Pick<
  OutboxEntry,
  "endpoint" | "method" | "body" | "entryType"
> {
  const { entryType, payload, cowId, farmId } = submission;

  switch (entryType) {
    case "feed":
      return {
        entryType,
        endpoint: "/feed_events",
        method: "POST",
        body: {
          feed_event: { ...(payload as FeedEventPayload), cow_id: cowId, farm_id: farmId },
        },
      };
    case "inhibitor":
      return {
        entryType,
        endpoint: "/inhibitor_doses",
        method: "POST",
        body: {
          inhibitor_dose: { ...(payload as InhibitorDosePayload), cow_id: cowId },
        },
      };
    case "grazing":
      return {
        entryType,
        endpoint: "/grazing_events",
        method: "POST",
        body: {
          grazing_event: {
            ...(payload as GrazingEventPayload),
            cow_id: cowId,
            farm_id: farmId,
          },
        },
      };
    case "health": {
      const health = payload as HealthObservationPayload;
      return {
        entryType,
        endpoint: `/cows/${cowId}`,
        method: "PUT",
        body: { cow: { status: health.status } },
      };
    }
  }
}

export async function submitDiaryEntry(
  submission: DiarySubmission,
  options: SubmitDiaryOptions,
): Promise<SubmitDiaryResult> {
  const route = routeSubmission(submission);
  const online = options.online ?? (typeof navigator !== "undefined" ? navigator.onLine : true);

  if (online) {
    try {
      await flushSingleEntry(options.resources, {
        id: "direct",
        ...route,
        cowId: submission.cowId,
        cowName: submission.cowName,
        status: "queued",
        createdAt: Date.now(),
        attempts: 0,
      });
      return { mode: "synced" };
    } catch {
      // fall through to queue on network/API failure
    }
  }

  const id = crypto.randomUUID();
  await enqueueOutbox({
    id,
    entryType: route.entryType,
    endpoint: route.endpoint,
    method: route.method,
    body: route.body,
    cowId: submission.cowId,
    cowName: submission.cowName,
    createdAt: Date.now(),
  });
  return { mode: "queued", outboxId: id };
}

async function flushSingleEntry(
  resources: FarmResources,
  entry: OutboxEntry,
): Promise<void> {
  switch (entry.entryType) {
    case "feed":
      await resources.createFeedEvent(entry.body.feed_event as FeedEventPayload);
      break;
    case "inhibitor":
      await resources.createInhibitorDose(entry.body.inhibitor_dose as InhibitorDosePayload);
      break;
    case "grazing":
      await resources.createGrazingEvent(entry.body.grazing_event as GrazingEventPayload);
      break;
    case "health": {
      const cow = entry.body.cow as { status: string };
      await resources.updateCow(entry.cowId, { status: cow.status });
      break;
    }
  }
}

export interface FlushResult {
  synced: number;
  failed: number;
}

export async function flushOutbox(resources: FarmResources): Promise<FlushResult> {
  const pending = await listPendingOutbox();
  let synced = 0;
  let failed = 0;

  for (const entry of pending) {
    await updateOutboxEntry(entry.id, { status: "syncing", attempts: entry.attempts + 1 });
    try {
      await flushSingleEntry(resources, entry);
      await updateOutboxEntry(entry.id, {
        status: "synced",
        syncedAt: Date.now(),
        lastError: undefined,
      });
      synced += 1;
    } catch (err) {
      failed += 1;
      await updateOutboxEntry(entry.id, {
        status: "failed",
        lastError: err instanceof Error ? err.message : "Sync failed",
      });
    }
  }

  return { synced, failed };
}

/** Background Sync is a bonus — primary flush uses online/reconnect events. */
export function registerBackgroundSyncBonus(): void {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return;
  void navigator.serviceWorker.ready.then(async (reg) => {
    if ("sync" in reg) {
      try {
        await (reg as ServiceWorkerRegistration & { sync: { register: (tag: string) => Promise<void> } }).sync.register("livestok-diary-sync");
      } catch {
        // unsupported or permission denied — foreground flush handles it
      }
    }
  });
}

export function isBackgroundSyncAvailable(): boolean {
  return typeof window !== "undefined" && "SyncManager" in window;
}
