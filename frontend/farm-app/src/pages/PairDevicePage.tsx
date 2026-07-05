import type { Cow, Device } from "@livestok/api";
import {
  buildPrintableQrUrl,
  executePairDevice,
  planPairDevice,
} from "@livestok/api";
import { Button, Card, Field, SelectInput, TextInput } from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { NfcPanel } from "../components/NfcPanel";
import { QrScanner } from "../components/QrScanner";
import { formatApiError, useAuth } from "../context/AuthContext";

type Step = "identify" | "link" | "done";

export function PairDevicePage() {
  const { id: repairDeviceId } = useParams();
  const [searchParams] = useSearchParams();
  const isRepair = Boolean(repairDeviceId);
  const navigate = useNavigate();
  const { user, resources } = useAuth();

  const [step, setStep] = useState<Step>("identify");
  const [serial, setSerial] = useState(searchParams.get("serial") ?? "");
  const [cowId, setCowId] = useState<number | "">("");
  const [cows, setCows] = useState<Cow[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [existingDevice, setExistingDevice] = useState<Device | null>(null);
  const [resultDevice, setResultDevice] = useState<Device | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const loadContext = useCallback(async () => {
    try {
      const [cowRes, deviceRes] = await Promise.all([
        resources.listCows({ limit: 200 }),
        resources.listDevices({ limit: 200 }),
      ]);
      setCows(cowRes.data);
      setDevices(deviceRes.data);

      if (repairDeviceId) {
        const { data: device } = await resources.getDevice(Number(repairDeviceId));
        setExistingDevice(device);
        setSerial(device.serial);
        if (device.cow?.id) setCowId(device.cow.id);
        setStep("link");
      }
    } catch (err) {
      setError(formatApiError(err));
    }
  }, [repairDeviceId, resources]);

  useEffect(() => {
    void loadContext();
  }, [loadContext]);

  useEffect(() => {
    const preset = searchParams.get("serial");
    if (preset && !repairDeviceId) {
      setSerial(preset);
      setStep("link");
    }
  }, [searchParams, repairDeviceId]);

  function handleSerialIdentified(value: string) {
    setSerial(value);
    const match = devices.find(
      (d) => d.serial.toLowerCase() === value.trim().toLowerCase(),
    );
    setExistingDevice(match ?? null);
    if (match?.cow?.id) setCowId(match.cow.id);
    setStep("link");
    setError("");
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!user?.farm_id || cowId === "") {
      setError("Select a cow and ensure your account has a farm.");
      return;
    }
    if (!serial.trim()) {
      setError("Identify the necklace first (QR, NFC, or manual ID).");
      return;
    }

    setLoading(true);
    setError("");
    try {
      const plan = planPairDevice(serial, user.farm_id, Number(cowId), devices);
      const device = await executePairDevice(resources, plan);
      setResultDevice(device);
      setStep("done");
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <Link to="/devices" className="text-sm font-semibold text-farm-primary">
        ← Back to devices
      </Link>

      <h2 className="text-xl font-bold">
        {isRepair ? "Re-pair necklace" : "Pair necklace"}
      </h2>

      {step === "identify" ? (
        <section className="space-y-4">
          <Card variant="farm">
            <p className="text-sm text-farm-text-muted">
              <strong className="text-farm-text">Step 1 — Identify the necklace.</strong>{" "}
              Scan the QR label (works on any phone). NFC is optional and only on Chrome for
              Android.
            </p>
          </Card>

          <QrScanner onSerial={handleSerialIdentified} />

          <NfcPanel onSerial={handleSerialIdentified} />

          <Field variant="farm" label="Or type device ID manually">
            <TextInput
              variant="farm"
              value={serial}
              placeholder="e.g. DEV-8842"
              onChange={(e) => setSerial(e.target.value)}
            />
          </Field>
          <Button
            variant="farm"
            type="button"
            className="w-full"
            disabled={!serial.trim()}
            onClick={() => handleSerialIdentified(serial.trim())}
          >
            Continue with this ID
          </Button>
        </section>
      ) : null}

      {step === "link" ? (
        <section className="space-y-4">
          <Card variant="farm">
            <p className="text-sm text-farm-text-muted">Device ID</p>
            <p className="font-mono text-lg font-bold text-farm-text">{serial}</p>
            {existingDevice?.cow ? (
              <p className="mt-2 text-sm text-farm-accent">
                Currently paired to {existingDevice.cow.name} — saving will move this necklace.
              </p>
            ) : null}
            {!isRepair ? (
              <button
                type="button"
                className="mt-2 text-sm font-semibold text-farm-primary underline"
                onClick={() => setStep("identify")}
              >
                Change device ID
              </button>
            ) : null}
          </Card>

          <form className="space-y-4" onSubmit={(e) => void handleSubmit(e)}>
            <Field variant="farm" label="Link to cow">
              <SelectInput
                variant="farm"
                required
                value={cowId === "" ? "" : String(cowId)}
                onChange={(e) => setCowId(Number(e.target.value))}
              >
                <option value="" disabled>
                  Select cow…
                </option>
                {cows.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name} ({c.breed})
                  </option>
                ))}
              </SelectInput>
            </Field>

            {error ? (
              <p className="text-sm text-farm-danger" role="alert">
                {error}
              </p>
            ) : null}

            <Button variant="farm" type="submit" className="w-full" disabled={loading}>
              {loading ? "Saving…" : isRepair ? "Move necklace to cow" : "Pair necklace"}
            </Button>
          </form>
        </section>
      ) : null}

      {step === "done" && resultDevice ? (
        <section className="space-y-4">
          <Card variant="farm">
            <p className="text-lg font-bold text-farm-success">Pairing saved</p>
            <p className="mt-2 text-farm-body">
              {resultDevice.serial} → {resultDevice.cow?.name ?? "cow"}
            </p>
            <img
              className="mt-3 rounded border border-farm-border"
              src={buildPrintableQrUrl(resultDevice.serial)}
              alt={`QR code for ${resultDevice.serial}`}
              width={200}
              height={200}
            />
            <p className="mt-2 text-xs text-farm-text-muted">
              Print this QR for the necklace if the label is missing.
            </p>
          </Card>

          <NfcPanel writeSerial={resultDevice.serial} onSerial={() => undefined} />

          <Button variant="farm" className="w-full" onClick={() => navigate("/devices")}>
            Done
          </Button>
        </section>
      ) : null}
    </div>
  );
}
