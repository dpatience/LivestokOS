import { parseDeviceQrPayload } from "@livestok/api";
import { BrowserQRCodeReader } from "@zxing/browser";
import { useCallback, useEffect, useRef, useState } from "react";
import { Button } from "@livestok/ui";

export type QrScanState =
  | { status: "idle" }
  | { status: "requesting" }
  | { status: "scanning" }
  | { status: "success"; serial: string }
  | { status: "denied"; message: string }
  | { status: "error"; message: string };

export interface QrScannerProps {
  onSerial: (serial: string) => void;
  disabled?: boolean;
}

export function QrScanner({ onSerial, disabled }: QrScannerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const readerRef = useRef<BrowserQRCodeReader | null>(null);
  const [state, setState] = useState<QrScanState>({ status: "idle" });

  const stop = useCallback(() => {
    readerRef.current?.reset();
    readerRef.current = null;
  }, []);

  const start = useCallback(async () => {
    if (disabled || !videoRef.current) return;
    stop();
    setState({ status: "requesting" });

    try {
      const reader = new BrowserQRCodeReader(undefined, {
        delayBetweenScanAttempts: 300,
        delayBetweenScanSuccess: 1500,
      });
      readerRef.current = reader;

      const devices = await BrowserQRCodeReader.listVideoInputDevices();
      const backCamera =
        devices.find((d) => /back|rear|environment/i.test(d.label))?.deviceId ??
        devices[0]?.deviceId;

      setState({ status: "scanning" });

      await reader.decodeFromVideoDevice(
        backCamera,
        videoRef.current,
        (result, err) => {
          if (result) {
            const serial = parseDeviceQrPayload(result.getText());
            if (serial) {
              setState({ status: "success", serial });
              onSerial(serial);
              stop();
            }
          }
          if (err && !(err.name === "NotFoundException")) {
            // continuous scan — ignore frame misses
          }
        },
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : "Camera scan failed.";
      if (/denied|not allowed|permission/i.test(message)) {
        setState({
          status: "denied",
          message:
            "Camera access was denied. Allow camera permission in browser settings, or enter the device ID manually below.",
        });
      } else {
        setState({ status: "error", message });
      }
      stop();
    }
  }, [disabled, onSerial, stop]);

  useEffect(() => () => stop(), [stop]);

  return (
    <div className="space-y-3">
      <div className="relative overflow-hidden rounded-farm border border-farm-border bg-black">
        <video ref={videoRef} className="aspect-[4/3] w-full object-cover" muted playsInline />
        {state.status === "idle" ? (
          <div className="absolute inset-0 flex items-center justify-center bg-farm-text/40 p-4 text-center text-sm font-semibold text-white">
            Tap “Scan QR code” to open the camera
          </div>
        ) : null}
      </div>

      <Button
        variant="farm"
        type="button"
        className="w-full"
        disabled={disabled || state.status === "scanning" || state.status === "requesting"}
        onClick={() => void start()}
      >
        {state.status === "scanning" ? "Scanning…" : "Scan QR code"}
      </Button>

      {state.status === "scanning" ? (
        <p className="text-sm text-farm-text-muted" role="status">
          Point the camera at the necklace QR label…
        </p>
      ) : null}

      {state.status === "success" ? (
        <p className="text-sm font-semibold text-farm-success" role="status">
          QR read OK — device ID: {state.serial}
        </p>
      ) : null}

      {state.status === "denied" || state.status === "error" ? (
        <p className="text-sm text-farm-danger" role="alert">
          {state.message}
        </p>
      ) : null}
    </div>
  );
}
