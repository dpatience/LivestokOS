export type CameraCapability =
  | { supported: true }
  | { supported: false; reason: string };

/**
 * Feature-detect camera access before opening the QR scanner.
 * Does not request permission — only checks API presence.
 */
export function getCameraCapability(): CameraCapability {
  if (typeof window === "undefined") {
    return { supported: false, reason: "Camera is not available during server render." };
  }
  if (!window.isSecureContext) {
    return {
      supported: false,
      reason: "Camera access requires HTTPS (or localhost). Use manual device ID entry instead.",
    };
  }
  if (!navigator.mediaDevices?.getUserMedia) {
    return {
      supported: false,
      reason:
        "This browser does not expose camera APIs (getUserMedia). Enter the device ID manually instead.",
    };
  }
  return { supported: true };
}
