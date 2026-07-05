import Dexie, { type EntityTable } from "dexie";
import type { DiaryEntryType } from "@livestok/api";

export type OutboxStatus = "queued" | "syncing" | "synced" | "failed";

export interface OutboxEntry {
  id: string;
  entryType: DiaryEntryType;
  endpoint: string;
  method: "POST" | "PUT";
  body: Record<string, unknown>;
  cowId: number;
  cowName: string;
  status: OutboxStatus;
  createdAt: number;
  syncedAt?: number;
  lastError?: string;
  attempts: number;
}

export type OutboxDb = Dexie & {
  outbox: EntityTable<OutboxEntry, "id">;
};

let dbInstance: OutboxDb | null = null;

export function getOutboxDb(): OutboxDb {
  if (!dbInstance) {
    dbInstance = new Dexie("LivestokFarmOutbox") as OutboxDb;
    dbInstance.version(1).stores({
      outbox: "id, status, createdAt, cowId",
    });
  }
  return dbInstance;
}

/** Test helper — swap IndexedDB implementation (fake-indexeddb in vitest). */
export function resetOutboxDbForTests(): void {
  if (dbInstance?.isOpen()) {
    void dbInstance.close();
  }
  dbInstance = null;
}

export async function enqueueOutbox(entry: Omit<OutboxEntry, "status" | "attempts">): Promise<void> {
  const db = getOutboxDb();
  await db.outbox.put({ ...entry, status: "queued", attempts: 0 });
}

export async function listPendingOutbox(): Promise<OutboxEntry[]> {
  const db = getOutboxDb();
  return db.outbox.where("status").anyOf(["queued", "failed"]).sortBy("createdAt");
}

export async function countOutboxByStatus(): Promise<Record<OutboxStatus, number>> {
  const db = getOutboxDb();
  const all = await db.outbox.toArray();
  return {
    queued: all.filter((e) => e.status === "queued").length,
    syncing: all.filter((e) => e.status === "syncing").length,
    synced: all.filter((e) => e.status === "synced").length,
    failed: all.filter((e) => e.status === "failed").length,
  };
}

export async function updateOutboxEntry(
  id: string,
  patch: Partial<OutboxEntry>,
): Promise<void> {
  const db = getOutboxDb();
  await db.outbox.update(id, patch);
}

export async function clearSyncedOutbox(olderThanMs = 86_400_000): Promise<void> {
  const db = getOutboxDb();
  const cutoff = Date.now() - olderThanMs;
  const old = await db.outbox.where("status").equals("synced").filter((e) => (e.syncedAt ?? 0) < cutoff).toArray();
  await db.outbox.bulkDelete(old.map((e) => e.id));
}
