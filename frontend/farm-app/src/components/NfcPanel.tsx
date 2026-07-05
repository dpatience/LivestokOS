import { Button, Card } from "@livestok/ui";
import type { NfcReadState, NfcWriteState } from "../lib/nfc";
import { getNfcCapability, nfcLimitationText, readNfcSerial, writeNfcSerial } from "../lib/nfc";
import { useState } from "react";

interface NfcPanelProps {
  onSerial: (serial: string) => void;
  writeSerial?: string | null;
  disabled?: boolean;
}

export function NfcPanel({ onSerial, writeSerial, disabled }: NfcPanelProps) {
  const cap = getNfcCapability();
  const [readState, setReadState] = useState<NfcReadState>({ status: "idle" });
  const [writeState, setWriteState] = useState<NfcWriteState>({ status: "idle" });

  if (!cap.supported) {
    return (
      <Card variant="farm" className="text-sm text-farm-text-muted">
        <p className="font-semibold text-farm-text">NFC fast path unavailable</p>
        <p className="mt-2">{cap.reason}</p>
        <p className="mt-2">Use the QR scanner above — it works on all phones with a camera.</p>
      </Card>
    );
  }

  async function handleRead() {
    setReadState({ status: "scanning" });
    const result = await readNfcSerial();
    setReadState(result);
    if (result.status === "success") {
      onSerial(result.serial);
    }
  }

  async function handleWrite() {
    if (!writeSerial) return;
    setWriteState({ status: "writing" });
    const result = await writeNfcSerial(writeSerial);
    setWriteState(result);
  }

  return (
    <div className="space-y-3">
      <Card variant="farm" className="text-sm text-farm-text-muted">
        <p className="font-semibold text-farm-text">NFC (Chrome on Android only)</p>
        <p className="mt-1">{nfcLimitationText()}</p>
      </Card>

      <Button
        variant="farm"
        type="button"
        className="w-full !bg-farm-accent"
        disabled={disabled || readState.status === "scanning"}
        onClick={() => void handleRead()}
      >
        {readState.status === "scanning" ? "Hold phone to necklace…" : "Tap to read NFC tag"}
      </Button>

      <NfcReadStatus state={readState} />

      {writeSerial ? (
        <>
          <Button
            variant="farm"
            type="button"
            className="w-full !bg-farm-surface-alt !text-farm-text border border-farm-border"
            disabled={disabled || writeState.status === "writing"}
            onClick={() => void handleWrite()}
          >
            {writeState.status === "writing"
              ? "Hold phone to blank tag…"
              : "Write UID to NFC tag (optional)"}
          </Button>
          <NfcWriteStatus state={writeState} />
        </>
      ) : null}
    </div>
  );
}

function NfcReadStatus({ state }: { state: NfcReadState }) {
  if (state.status === "idle") return null;
  if (state.status === "scanning") {
    return (
      <p className="text-sm text-farm-text-muted" role="status">
        Scanning — keep the phone against the tag…
      </p>
    );
  }
  if (state.status === "success") {
    return (
      <p className="text-sm font-semibold text-farm-success" role="status">
        NFC read OK — device ID: {state.serial}
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
      NFC read failed: {state.message}
    </p>
  );
}

function NfcWriteStatus({ state }: { state: NfcWriteState }) {
  if (state.status === "idle" || state.status === "writing") return null;
  if (state.status === "success") {
    return (
      <p className="text-sm font-semibold text-farm-success" role="status">
        NFC write OK — tag programmed.
      </p>
    );
  }
  if (state.status === "timeout") {
    return (
      <p className="text-sm text-farm-accent" role="alert">
        NFC write timed out: {state.message}
      </p>
    );
  }
  return (
    <p className="text-sm text-farm-danger" role="alert">
      NFC write failed: {state.message}
    </p>
  );
}
