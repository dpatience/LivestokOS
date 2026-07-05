import {
  formatDeviceQrPayload,
  parseDeviceQrPayload,
  planPairDevice,
  planUnpairDevice,
} from "@livestok/api";
import { describe, expect, it } from "vitest";

describe("parseDeviceQrPayload", () => {
  it("parses livestok prefix", () => {
    expect(parseDeviceQrPayload("livestok:necklace:DEV-123")).toBe("DEV-123");
  });

  it("parses plain serial", () => {
    expect(parseDeviceQrPayload("COW-COLLAR-99")).toBe("COW-COLLAR-99");
  });

  it("rejects garbage", () => {
    expect(parseDeviceQrPayload("")).toBeNull();
    expect(parseDeviceQrPayload("!!!")).toBeNull();
  });
});

describe("formatDeviceQrPayload", () => {
  it("wraps serial for QR labels", () => {
    expect(formatDeviceQrPayload("ABC")).toBe("livestok:necklace:ABC");
  });
});

describe("planPairDevice", () => {
  const devices = [
    {
      id: 1,
      serial: "DEV-1",
      hardware_type: "necklace",
      firmware_version: null,
      status: "online",
      last_seen_at: null,
      metadata: {},
      cow: null,
      farm_id: 10,
    },
  ];

  it("creates when serial is new", () => {
    const plan = planPairDevice("NEW-9", 10, 5, devices);
    expect(plan.action).toBe("create");
    expect(plan.payload.serial).toBe("NEW-9");
    expect(plan.payload.cow_id).toBe(5);
    expect(plan.payload.hardware_type).toBe("necklace");
  });

  it("updates when serial exists (re-pair)", () => {
    const plan = planPairDevice("DEV-1", 10, 7, devices);
    expect(plan.action).toBe("update");
    expect(plan.deviceId).toBe(1);
    expect(plan.payload.cow_id).toBe(7);
  });
});

describe("planUnpairDevice", () => {
  it("clears cow_id via PUT", () => {
    expect(planUnpairDevice()).toEqual({ cow_id: null });
  });
});
