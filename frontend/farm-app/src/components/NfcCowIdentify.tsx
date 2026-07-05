import type { Device } from "@livestok/api";
import { Button, Card, Smartphone } from "@livestok/ui";
import { useState } from "react";
import { getNfcCapability, nfcLimitationText, readNfcSerial } from "../lib/nfc";
import type { NfcReadState } from "../lib/nfc";

export interface IdentifiedCow {
  id: number;
  name: string;
  source: "nfc" | "search";
}

interface NfcCowIdentifyProps {
  devices: Device[];
  onCow: (cow: IdentifiedCow) => void;
  disabled?: boolean;
}

export function NfcCowIdentify({ devices, onCow, disabled }: NfcCowIdentifyProps) {
  const cap = getNfcCapability();
  const [state, setState] = useState<NfcReadState>({ status: "idle" });

  async function handleTap() {
    setState({ status: "scanning" });
    const result = await readNfcSerial();
    setState(result);
    if (result.status !== "success") return;

    const device = devices.find(
      (d) => d.serial.toLowerCase() === result.serial.toLowerCase(),
    );
    if (!device?.cow) {
      setState({
        status: "error",
        message: `Necklace ${result.serial} is not paired to a cow. Pair it first or use search below.`,
      });
      return;
    }

    onCow({ id: device.cow.id, name: device.cow.name, source: "nfc" });
  }

  if (!cap.supported) {
    return (
      <Card variant="farm" className="text-sm text-farm-text-muted">
        <p className="font-semibold text-farm-text">NFC unavailable on this device</p>
        <p className="mt-1">{cap.reason}</p>
        <p className="mt-2">Use the cow search below instead.</p>
      </Card>
    );
  }

  return (
    <div className="space-y-2">
      <Button
        variant="farm"
        type="button"
        className="h-auto w-full !min-h-tap flex-col gap-2 py-5 text-lg"
        disabled={disabled || state.status === "scanning"}
        onClick={() => void handleTap()}
      >
        <Smartphone size={32} aria-hidden />
        {state.status === "scanning" ? "Hold phone to necklace…" : "Tap necklace (NFC)"}
      </Button>
      <p className="text-xs text-farm-text-muted">{nfcLimitationText()}</p>
      <NfcStatus state={state} />
    </div>
  );
}

function NfcStatus({ state }: { state: NfcReadState }) {
  if (state.status === "idle" || state.status === "scanning") return null;
  if (state.status === "success") {
    return (
      <p className="text-sm font-semibold text-farm-success" role="status">
        Tag read — looking up cow…
      </p>
    );
  }
  if (state.status === "timeout") {
    return (
      <p className="text-sm text-farm-accent" role="alert">
        NFC timed out: {state.message}
      </p>
    );
  }
  return (
    <p className="text-sm text-farm-danger" role="alert">
      NFC failed: {state.message}
    </p>
  );
}
