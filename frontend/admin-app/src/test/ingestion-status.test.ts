import { describe, expect, it } from "vitest";
import {
  formatIngestionErrors,
  ingestionDisplayStatus,
  ingestionStatusLabel,
  ingestionStatusTone,
} from "../lib/ingestion-status";

describe("ingestion status helpers", () => {
  it("maps Oban states to display buckets", () => {
    expect(ingestionDisplayStatus("completed")).toBe("success");
    expect(ingestionDisplayStatus("executing")).toBe("in_progress");
    expect(ingestionDisplayStatus("discarded")).toBe("error");
    expect(ingestionDisplayStatus("never_run")).toBe("idle");
  });

  it("provides semantic tone and human labels", () => {
    expect(ingestionStatusTone("success")).toBe("success");
    expect(ingestionStatusTone("in_progress")).toBe("warning");
    expect(ingestionStatusLabel("retryable")).toBe("Retrying");
  });

  it("formats error payloads for display", () => {
    expect(formatIngestionErrors([])).toBeNull();
    expect(formatIngestionErrors(["fetch failed"])).toBe("fetch failed");
  });
});
