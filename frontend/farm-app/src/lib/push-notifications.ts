import type { Alert } from "@livestok/api";
import { alertDomain } from "@livestok/api";

export interface PushCapability {
  supported: boolean;
  reason?: string;
  /** iOS Safari requires PWA installed to home screen before push works. */
  iosNeedsInstall: boolean;
}

export function getPushCapability(): PushCapability {
  if (typeof window === "undefined") {
    return { supported: false, reason: "Not in browser", iosNeedsInstall: false };
  }

  const isIos =
    /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isStandalone =
    (typeof window.matchMedia === "function" &&
      window.matchMedia("(display-mode: standalone)").matches) ||
    ("standalone" in navigator && (navigator as Navigator & { standalone?: boolean }).standalone);

  if (!("Notification" in window) || !("serviceWorker" in navigator)) {
    return {
      supported: false,
      reason: "Push notifications require a browser with Notification + Service Worker support.",
      iosNeedsInstall: isIos,
    };
  }

  if (isIos && !isStandalone) {
    return {
      supported: false,
      reason:
        "On iPhone/iPad, push notifications only work after you install this app to your Home Screen (Share → Add to Home Screen). Safari in a tab cannot receive push.",
      iosNeedsInstall: true,
    };
  }

  return { supported: true, iosNeedsInstall: isIos };
}

export function isBackgroundSyncAvailable(): boolean {
  return typeof window !== "undefined" && "SyncManager" in window;
}

export async function requestNotificationPermission(): Promise<NotificationPermission> {
  const cap = getPushCapability();
  if (!cap.supported) return "denied";
  return Notification.requestPermission();
}

export async function showAlertViaServiceWorker(alert: Alert): Promise<void> {
  if (Notification.permission !== "granted") return;
  if (!("serviceWorker" in navigator)) return;

  const reg = await navigator.serviceWorker.ready;
  const domain = alertDomain(alert);
  const title =
    domain === "calving"
      ? "Calving alert"
      : domain === "health"
        ? "Health alert"
        : "Urgent farm alert";

  if (reg.active) {
    reg.active.postMessage({
      type: "SHOW_ALERT_NOTIFICATION",
      payload: { title, body: alert.message, tag: `alert-${alert.id}` },
    });
  } else {
    await reg.showNotification(title, {
      body: alert.message,
      tag: `alert-${alert.id}`,
      icon: "/icon-192.png",
      requireInteraction: true,
    });
  }
}

/** Bonus: subscribe to Web Push when VAPID key is configured (server endpoint TBD). */
export async function subscribeToPushBonus(): Promise<PushSubscription | null> {
  const vapidKey = import.meta.env.VITE_VAPID_PUBLIC_KEY as string | undefined;
  if (!vapidKey || !("PushManager" in window)) return null;

  const reg = await navigator.serviceWorker.ready;
  const existing = await reg.pushManager.getSubscription();
  if (existing) return existing;

  try {
    return await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidKey),
    });
  } catch {
    return null;
  }
}

function urlBase64ToUint8Array(base64String: string): Uint8Array<ArrayBuffer> {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  const buffer = new ArrayBuffer(raw.length);
  const out = new Uint8Array(buffer);
  for (let i = 0; i < raw.length; i += 1) out[i] = raw.charCodeAt(i);
  return out;
}
