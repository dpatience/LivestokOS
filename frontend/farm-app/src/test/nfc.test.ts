import { describe, expect, it, afterEach } from "vitest";
import { getNfcCapability, nfcLimitationText } from "../lib/nfc";

describe("getNfcCapability", () => {
  const original = globalThis.window;

  afterEach(() => {
    Object.defineProperty(globalThis, "window", { value: original, configurable: true });
  });

  it("reports unsupported when NDEFReader is missing", () => {
    Object.defineProperty(globalThis, "window", {
      value: { isSecureContext: true },
      configurable: true,
    });
    const cap = getNfcCapability();
    expect(cap.supported).toBe(false);
    if (!cap.supported) {
      expect(cap.reason).toContain("Chrome on Android");
      expect(cap.reason).toContain("iPhone");
    }
  });

  it("reports supported when NDEFReader exists on HTTPS", () => {
    Object.defineProperty(globalThis, "window", {
      value: { isSecureContext: true, NDEFReader: class {} },
      configurable: true,
    });
    expect(getNfcCapability()).toEqual({ supported: true });
  });

  it("requires secure context", () => {
    Object.defineProperty(globalThis, "window", {
      value: { isSecureContext: false, NDEFReader: class {} },
      configurable: true,
    });
    const cap = getNfcCapability();
    expect(cap.supported).toBe(false);
  });
});

describe("nfcLimitationText", () => {
  it("mentions platform limits for in-app copy", () => {
    expect(nfcLimitationText()).toMatch(/iPhone\/iPad Safari/i);
    expect(nfcLimitationText()).toMatch(/Chrome on Android/i);
  });
});
