import type { DiaryEntryType } from "@livestok/api";
import { Button, Field, SelectInput, TextInput } from "@livestok/ui";
import { useState } from "react";
import type { DiarySubmission } from "../lib/diary-sync";

const ENTRY_TYPES: { type: DiaryEntryType; label: string; icon: string }[] = [
  { type: "feed", label: "Feed", icon: "🌾" },
  { type: "inhibitor", label: "Medication", icon: "💊" },
  { type: "health", label: "Health", icon: "🩺" },
  { type: "grazing", label: "Grazing", icon: "🌿" },
];

const FEED_PRESETS = ["Hay", "Silage", "Concentrate", "Mineral"];
const INHIBITOR_PRESETS = ["3-NOP", "Seaweed extract", "Other"];
const HEALTH_STATUSES = ["healthy", "sick", "quarantine", "dry"];

function nowIso(): string {
  return new Date().toISOString();
}

interface DiaryEntryFormProps {
  cowId: number;
  cowName: string;
  farmId?: number;
  onSubmit: (submission: DiarySubmission) => Promise<void>;
  loading?: boolean;
}

export function DiaryEntryForm({
  cowId,
  cowName,
  farmId,
  onSubmit,
  loading,
}: DiaryEntryFormProps) {
  const [entryType, setEntryType] = useState<DiaryEntryType>("feed");
  const [feedType, setFeedType] = useState(FEED_PRESETS[0]);
  const [quantityKg, setQuantityKg] = useState("5");
  const [inhibitorType, setInhibitorType] = useState(INHIBITOR_PRESETS[0]);
  const [doseMg, setDoseMg] = useState("200");
  const [zoneId, setZoneId] = useState("");
  const [healthStatus, setHealthStatus] = useState("healthy");
  const [notes, setNotes] = useState("");

  async function handleSave() {
    const base = { entryType, cowId, cowName, farmId };
    switch (entryType) {
      case "feed":
        await onSubmit({
          ...base,
          payload: {
            feed_type: feedType,
            quantity_kg: Number(quantityKg),
            fed_at: nowIso(),
            cow_id: cowId,
            farm_id: farmId,
            notes: notes || undefined,
          },
        });
        break;
      case "inhibitor":
        await onSubmit({
          ...base,
          payload: {
            inhibitor_type: inhibitorType,
            dose_mg: Number(doseMg),
            administered_at: nowIso(),
            cow_id: cowId,
            notes: notes || undefined,
          },
        });
        break;
      case "grazing":
        await onSubmit({
          ...base,
          payload: {
            zone_id: zoneId.trim() || "paddock",
            entered_at: nowIso(),
            cow_id: cowId,
            farm_id: farmId,
          },
        });
        break;
      case "health":
        await onSubmit({
          ...base,
          payload: { cow_id: cowId, status: healthStatus },
        });
        break;
    }
    setNotes("");
  }

  return (
    <div className="space-y-4">
      <p className="text-farm-body font-bold text-farm-text">Log for {cowName}</p>

      <div className="grid grid-cols-2 gap-2">
        {ENTRY_TYPES.map((t) => (
          <button
            key={t.type}
            type="button"
            className={`tap-target flex flex-col items-center justify-center rounded-farm border-2 py-4 ${
              entryType === t.type
                ? "border-farm-primary bg-farm-primary/10"
                : "border-farm-border"
            }`}
            onClick={() => setEntryType(t.type)}
          >
            <span className="text-2xl" aria-hidden>
              {t.icon}
            </span>
            <span className="text-sm font-semibold">{t.label}</span>
          </button>
        ))}
      </div>

      {entryType === "feed" ? (
        <>
          <div className="flex flex-wrap gap-2">
            {FEED_PRESETS.map((p) => (
              <button
                key={p}
                type="button"
                className={`tap-target rounded-full px-4 py-2 text-sm font-semibold ${
                  feedType === p ? "bg-farm-primary text-white" : "bg-farm-surface-alt border border-farm-border"
                }`}
                onClick={() => setFeedType(p)}
              >
                {p}
              </button>
            ))}
          </div>
          <Field variant="farm" label="Quantity (kg)">
            <TextInput variant="farm" inputMode="decimal" value={quantityKg} onChange={(e) => setQuantityKg(e.target.value)} />
          </Field>
        </>
      ) : null}

      {entryType === "inhibitor" ? (
        <>
          <Field variant="farm" label="Inhibitor type">
            <SelectInput variant="farm" value={inhibitorType} onChange={(e) => setInhibitorType(e.target.value)}>
              {INHIBITOR_PRESETS.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field variant="farm" label="Dose (mg)">
            <TextInput variant="farm" inputMode="decimal" value={doseMg} onChange={(e) => setDoseMg(e.target.value)} />
          </Field>
        </>
      ) : null}

      {entryType === "grazing" ? (
        <Field variant="farm" label="Paddock / zone">
          <TextInput variant="farm" placeholder="North paddock" value={zoneId} onChange={(e) => setZoneId(e.target.value)} />
        </Field>
      ) : null}

      {entryType === "health" ? (
        <>
          <Field variant="farm" label="Health status">
            <SelectInput variant="farm" value={healthStatus} onChange={(e) => setHealthStatus(e.target.value)}>
              {HEALTH_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </SelectInput>
          </Field>
          <p className="text-xs text-farm-text-muted">
            Backend note: no dedicated health-log endpoint — updates cow status via PUT /api/cows/:id.
          </p>
        </>
      ) : null}

      {entryType !== "health" ? (
        <Field variant="farm" label="Notes (optional)">
          <TextInput variant="farm" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>
      ) : null}

      <Button variant="farm" type="button" className="w-full py-4 text-lg" disabled={loading} onClick={() => void handleSave()}>
        {loading ? "Saving…" : "Log entry"}
      </Button>
    </div>
  );
}
