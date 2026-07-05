import { Button, Card } from "@livestok/ui";
import { useState } from "react";
import {
  getPushCapability,
  requestNotificationPermission,
  subscribeToPushBonus,
} from "../lib/push-notifications";

interface PushNotificationSettingsProps {
  onEnabled?: () => void;
}

export function PushNotificationSettings({ onEnabled }: PushNotificationSettingsProps) {
  const cap = getPushCapability();
  const [permission, setPermission] = useState<NotificationPermission>(
    typeof Notification !== "undefined" ? Notification.permission : "default",
  );
  const [busy, setBusy] = useState(false);

  async function handleEnable() {
    setBusy(true);
    try {
      const result = await requestNotificationPermission();
      setPermission(result);
      if (result === "granted") {
        await subscribeToPushBonus();
        onEnabled?.();
      }
    } finally {
      setBusy(false);
    }
  }

  if (!cap.supported) {
    return (
      <Card variant="farm" className="border border-farm-accent/40 bg-farm-accent/5">
        <p className="font-semibold text-farm-accent">Push notifications unavailable</p>
        <p className="mt-1 text-sm text-farm-text-muted">{cap.reason}</p>
        {cap.iosNeedsInstall ? (
          <p className="mt-2 text-sm font-semibold text-farm-text">
            iOS: Open Safari → Share → <strong>Add to Home Screen</strong>, then open the installed
            app and enable notifications here.
          </p>
        ) : null}
      </Card>
    );
  }

  if (permission === "granted") {
    return (
      <Card variant="farm">
        <p className="font-semibold text-farm-success">Push notifications enabled</p>
        <p className="mt-1 text-sm text-farm-text-muted">
          High-severity calving and health alerts will notify you via the service worker.
        </p>
      </Card>
    );
  }

  return (
    <Card variant="farm">
      <p className="font-semibold">Get notified for urgent alerts</p>
      <p className="mt-1 text-sm text-farm-text-muted">
        Enable push for calving and health alerts. We ask permission here — not on first load.
      </p>
      {cap.iosNeedsInstall ? (
        <p className="mt-2 text-xs text-farm-accent">
          iPhone/iPad: install this PWA to Home Screen first, or push will not work.
        </p>
      ) : null}
      <Button
        variant="farm"
        type="button"
        className="mt-3 w-full"
        disabled={busy || permission === "denied"}
        onClick={() => void handleEnable()}
      >
        {permission === "denied" ? "Notifications blocked in browser settings" : "Enable push notifications"}
      </Button>
    </Card>
  );
}
