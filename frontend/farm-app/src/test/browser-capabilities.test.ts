import { afterEach, describe, expect, it, vi } from "vitest";
import { getCameraCapability } from "../lib/camera";
import {
  getPushCapability,
  isBackgroundSyncAvailable,
} from "../lib/push-notifications";

describe("getCameraCapability", () => {
  const originalNavigator = globalThis.navigator;

  afterEach(() => {
    Object.defineProperty(globalThis, "navigator", {
      value: originalNavigator,
      configurable: true,
    });
  });

  it("reports unsupported without getUserMedia", () => {
    Object.defineProperty(globalThis, "navigator", {
      value: { mediaDevices: {} },
      configurable: true,
    });
    Object.defineProperty(globalThis, "window", {
      value: { isSecureContext: true },
      configurable: true,
    });
    const cap = getCameraCapability();
    expect(cap.supported).toBe(false);
    if (!cap.supported) expect(cap.reason).toContain("getUserMedia");
  });

  it("reports supported on HTTPS with getUserMedia", () => {
    Object.defineProperty(globalThis, "navigator", {
      value: { mediaDevices: { getUserMedia: vi.fn() } },
      configurable: true,
    });
    Object.defineProperty(globalThis, "window", {
      value: { isSecureContext: true },
      configurable: true,
    });
    expect(getCameraCapability()).toEqual({ supported: true });
  });
});

describe("getPushCapability", () => {
  const originalWindow = globalThis.window;
  const originalNavigator = globalThis.navigator;

  afterEach(() => {
    Object.defineProperty(globalThis, "window", { value: originalWindow, configurable: true });
    Object.defineProperty(globalThis, "navigator", {
      value: originalNavigator,
      configurable: true,
    });
  });

  it("reports unsupported when Notification API is missing", () => {
    Object.defineProperty(globalThis, "window", {
      value: {
        matchMedia: () => ({ matches: false }),
      },
      configurable: true,
    });
    Object.defineProperty(globalThis, "navigator", {
      value: { userAgent: "Chrome" },
      configurable: true,
    });
    const cap = getPushCapability();
    expect(cap.supported).toBe(false);
  });

  it("reports iOS needs install when not standalone", () => {
    Object.defineProperty(globalThis, "window", {
      value: {
        Notification: {},
        matchMedia: () => ({ matches: false }),
      },
      configurable: true,
    });
    Object.defineProperty(globalThis, "navigator", {
      value: { userAgent: "iPhone", serviceWorker: {} },
      configurable: true,
    });
    const cap = getPushCapability();
    expect(cap.supported).toBe(false);
    expect(cap.iosNeedsInstall).toBe(true);
    if (!cap.supported) expect(cap.reason).toContain("Home Screen");
  });
});

describe("isBackgroundSyncAvailable", () => {
  it("is false without SyncManager", () => {
    Object.defineProperty(globalThis, "window", {
      value: {},
      configurable: true,
    });
    expect(isBackgroundSyncAvailable()).toBe(false);
  });

  it("is true when SyncManager exists", () => {
    Object.defineProperty(globalThis, "window", {
      value: { SyncManager: class {} },
      configurable: true,
    });
    expect(isBackgroundSyncAvailable()).toBe(true);
  });
});
