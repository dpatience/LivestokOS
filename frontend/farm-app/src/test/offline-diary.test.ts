import "fake-indexeddb/auto";
import type { FarmResources } from "@livestok/api";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  countOutboxByStatus,
  getOutboxDb,
  listPendingOutbox,
  resetOutboxDbForTests,
} from "../db/outbox";
import { flushOutbox, submitDiaryEntry } from "../lib/diary-sync";

function mockResources(): FarmResources {
  return {
    createFeedEvent: vi.fn().mockResolvedValue({ data: { id: 1 } }),
    createInhibitorDose: vi.fn().mockResolvedValue({ data: { id: 1 } }),
    createGrazingEvent: vi.fn().mockResolvedValue({ data: { id: 1 } }),
    updateCow: vi.fn().mockResolvedValue({ data: { id: 1 } }),
  } as unknown as FarmResources;
}

describe("offline diary outbox", () => {
  beforeEach(async () => {
    resetOutboxDbForTests();
    await getOutboxDb().open();
  });

  afterEach(async () => {
    const db = getOutboxDb();
    await db.outbox.clear();
    await db.close();
    resetOutboxDbForTests();
  });

  it("queues entry when offline, then flushes on reconnect", async () => {
    const resources = mockResources();

    const result = await submitDiaryEntry(
      {
        entryType: "feed",
        cowId: 42,
        cowName: "Bessie",
        farmId: 7,
        payload: {
          feed_type: "Hay",
          quantity_kg: 5,
          fed_at: "2026-07-05T10:00:00.000Z",
          cow_id: 42,
          farm_id: 7,
        },
      },
      { resources, online: false },
    );

    expect(result.mode).toBe("queued");
    expect(result.outboxId).toBeTruthy();

    const pending = await listPendingOutbox();
    expect(pending).toHaveLength(1);
    expect(pending[0]?.status).toBe("queued");
    expect(pending[0]?.cowName).toBe("Bessie");
    expect(pending[0]?.entryType).toBe("feed");

    const countsBefore = await countOutboxByStatus();
    expect(countsBefore.queued).toBe(1);
    expect(countsBefore.synced).toBe(0);

    const flushResult = await flushOutbox(resources);
    expect(flushResult.synced).toBe(1);
    expect(flushResult.failed).toBe(0);
    expect(resources.createFeedEvent).toHaveBeenCalledOnce();
    expect(resources.createFeedEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        feed_type: "Hay",
        quantity_kg: 5,
        cow_id: 42,
        farm_id: 7,
      }),
    );

    const pendingAfter = await listPendingOutbox();
    expect(pendingAfter).toHaveLength(0);

    const countsAfter = await countOutboxByStatus();
    expect(countsAfter.synced).toBe(1);
    expect(countsAfter.queued).toBe(0);
    expect(countsAfter.failed).toBe(0);
  });

  it("queues when online but API fails, then retries successfully", async () => {
    const resources = mockResources();
    vi.mocked(resources.createFeedEvent).mockRejectedValueOnce(new Error("Network error"));

    const first = await submitDiaryEntry(
      {
        entryType: "feed",
        cowId: 1,
        cowName: "Daisy",
        payload: {
          feed_type: "Silage",
          quantity_kg: 3,
          fed_at: "2026-07-05T11:00:00.000Z",
          cow_id: 1,
        },
      },
      { resources, online: true },
    );

    expect(first.mode).toBe("queued");
    expect(await listPendingOutbox()).toHaveLength(1);

    vi.mocked(resources.createFeedEvent).mockResolvedValueOnce({ data: { id: 99 } } as never);

    const flushResult = await flushOutbox(resources);
    expect(flushResult.synced).toBe(1);
    expect((await countOutboxByStatus()).synced).toBe(1);
  });
});
