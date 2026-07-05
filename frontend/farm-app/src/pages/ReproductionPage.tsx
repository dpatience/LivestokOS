import type { Alert, Cow } from "@livestok/api";
import { Button, Card, Field, SelectInput, TextInput, farmChip } from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { AlertCard } from "../components/AlertCard";
import { useAuth } from "../context/AuthContext";
import { formatApiError } from "../context/AuthContext";

type ReproTab = "heat" | "breeding" | "calving" | "lactation" | "dryoff";

export function ReproductionPage() {
  const { user, resources, reproduction, operations } = useAuth();
  const [tab, setTab] = useState<ReproTab>("breeding");
  const [cows, setCows] = useState<Cow[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [breeding, setBreeding] = useState<Awaited<ReturnType<typeof reproduction.listBreedingRecords>>["data"]>([]);
  const [gestations, setGestations] = useState<Awaited<ReturnType<typeof reproduction.listGestations>>["data"]>([]);
  const [lactation, setLactation] = useState<Awaited<ReturnType<typeof reproduction.listLactationRecords>>["data"]>([]);
  const [dryOff, setDryOff] = useState<Awaited<ReturnType<typeof reproduction.listDryOffSchedules>>["data"]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const farmId = user?.farm_id;

  const refresh = useCallback(async () => {
    const [cowRes, breedRes, gestRes, lactRes, dryRes, alertRes] = await Promise.all([
      resources.listCows({ limit: 200 }),
      reproduction.listBreedingRecords(),
      reproduction.listGestations(),
      reproduction.listLactationRecords(),
      reproduction.listDryOffSchedules(),
      operations.listAlerts({ limit: 100 }),
    ]);
    setCows(cowRes.data);
    setBreeding(breedRes.data);
    setGestations(gestRes.data);
    setLactation(lactRes.data);
    setDryOff(dryRes.data);
    setAlerts(alertRes.data);
  }, [resources, reproduction, operations]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const heatAlerts = alerts.filter(
    (a) => a.type === "ESTRUS_PROXY" || a.type === "estrus_proxy",
  );

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Reproduction &amp; dairy</h2>
      <p className="text-sm text-farm-text-muted">
        Wired to Stage 5 backend schemas (breeding_records, gestation_records, lactation_records,
        dry_off_schedules, calving_events). Heat detection uses ESTRUS_PROXY alerts — no heat_cycles
        table exists.
      </p>

      <div className="flex flex-wrap gap-2">
        {(
          [
            ["heat", "Heat window"],
            ["breeding", "Breeding"],
            ["calving", "Calving"],
            ["lactation", "Lactation"],
            ["dryoff", "Dry-off"],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            type="button"
            className={`${farmChip} ${
              tab === key ? "border-farm-primary bg-farm-primary text-white" : "border-farm-border hover:border-farm-primary/40"
            }`}
            onClick={() => setTab(key)}
          >
            {label}
          </button>
        ))}
      </div>

      {error ? (
        <Card variant="farm">
          <p className="text-sm text-farm-danger">{error}</p>
        </Card>
      ) : null}

      {tab === "heat" ? (
        <HeatTab alerts={heatAlerts} />
      ) : null}
      {tab === "breeding" ? (
        <BreedingTab
          cows={cows}
          records={breeding}
          farmId={farmId}
          loading={loading}
          onRefresh={refresh}
          onError={setError}
        />
      ) : null}
      {tab === "calving" ? (
        <CalvingTab
          cows={cows}
          gestations={gestations}
          farmId={farmId}
          loading={loading}
          onRefresh={refresh}
          onError={setError}
        />
      ) : null}
      {tab === "lactation" ? (
        <LactationTab
          cows={cows}
          records={lactation}
          farmId={farmId}
          loading={loading}
          onRefresh={refresh}
          onError={setError}
        />
      ) : null}
      {tab === "dryoff" ? (
        <DryOffTab schedules={dryOff} gestations={gestations} onRefresh={refresh} onError={setError} />
      ) : null}
    </div>
  );
}

function HeatTab({ alerts }: { alerts: Alert[] }) {
  return (
    <Card variant="farm">
      <h3 className="font-bold">Heat-cycle proxy windows</h3>
      <p className="mt-1 text-sm text-farm-text-muted">
        Backend uses behavioral proxy (grazing ↑, rumination ↓) — not a dedicated heat_cycles table.
        Alerts type <code className="text-xs">ESTRUS_PROXY</code> when score ≥ 0.60.
      </p>
      {alerts.length === 0 ? (
        <p className="mt-3 text-sm">No active estrus proxy alerts.</p>
      ) : (
        <ul className="mt-3 space-y-2">
          {alerts.map((a) => (
            <li key={a.id}>
              <AlertCard alert={a} compact />
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

function BreedingTab({
  cows,
  records,
  farmId,
  loading,
  onRefresh,
  onError,
}: {
  cows: Cow[];
  records: Awaited<ReturnType<import("@livestok/api").ReproductionResources["listBreedingRecords"]>>["data"];
  farmId?: number;
  loading: boolean;
  onRefresh: () => Promise<void>;
  onError: (m: string | null) => void;
}) {
  const { reproduction } = useAuth();
  const [cowId, setCowId] = useState("");
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [method, setMethod] = useState<"ai" | "natural">("ai");
  const [sireRef, setSireRef] = useState("");

  async function handleCreate() {
    if (!cowId || !farmId) return;
    onError(null);
    try {
      await reproduction.createBreedingRecord({
        cow_id: Number(cowId),
        farm_id: farmId,
        insemination_date: date,
        method,
        sire_reference: sireRef || undefined,
      });
      await onRefresh();
    } catch (e) {
      onError(formatApiError(e));
    }
  }

  async function handleConfirm(id: number) {
    onError(null);
    try {
      await reproduction.confirmBreeding(id);
      await onRefresh();
    } catch (e) {
      onError(formatApiError(e));
    }
  }

  return (
    <div className="space-y-4">
      <Card variant="farm">
        <h3 className="font-bold">New breeding record</h3>
        <div className="mt-3 space-y-3">
          <Field variant="farm" label="Cow">
            <SelectInput variant="farm" value={cowId} onChange={(e) => setCowId(e.target.value)}>
              <option value="">Select…</option>
              {cows.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field variant="farm" label="insemination_date">
            <TextInput variant="farm" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </Field>
          <Field variant="farm" label="method">
            <SelectInput variant="farm" value={method} onChange={(e) => setMethod(e.target.value as "ai" | "natural")}>
              <option value="ai">ai</option>
              <option value="natural">natural</option>
            </SelectInput>
          </Field>
          <Field variant="farm" label="sire_reference (optional)">
            <TextInput variant="farm" value={sireRef} onChange={(e) => setSireRef(e.target.value)} />
          </Field>
          <Button variant="farm" type="button" disabled={loading} onClick={() => void handleCreate()}>
            Save breeding record
          </Button>
        </div>
      </Card>

      <Card variant="farm">
        <h3 className="font-bold">Breeding records</h3>
        <ul className="mt-2 space-y-2">
          {records.map((r) => (
            <li key={r.id} className="rounded-farm border border-farm-border p-3 text-sm">
              <p className="font-semibold">Cow #{r.cow_id}</p>
              <p>
                {r.insemination_date} · {r.method} · {r.outcome}
              </p>
              {r.outcome === "pending" ? (
                <Button
                  variant="farm"
                  type="button"
                  className="mt-2 !min-h-10 text-xs"
                  onClick={() => void handleConfirm(r.id)}
                >
                  Confirm pregnant → creates gestation + dry-off
                </Button>
              ) : null}
            </li>
          ))}
          {records.length === 0 ? <p className="text-sm text-farm-text-muted">No records yet.</p> : null}
        </ul>
      </Card>
    </div>
  );
}

function CalvingTab({
  cows,
  gestations,
  farmId,
  loading,
  onRefresh,
  onError,
}: {
  cows: Cow[];
  gestations: Awaited<ReturnType<import("@livestok/api").ReproductionResources["listGestations"]>>["data"];
  farmId?: number;
  loading: boolean;
  onRefresh: () => Promise<void>;
  onError: (m: string | null) => void;
}) {
  const { reproduction } = useAuth();
  const [cowId, setCowId] = useState("");
  const [difficulty, setDifficulty] = useState<"easy" | "assisted" | "veterinary">("easy");

  async function handleCalving() {
    if (!cowId || !farmId) return;
    onError(null);
    try {
      await reproduction.createCalvingEvent({
        cow_id: Number(cowId),
        farm_id: farmId,
        occurred_at: new Date().toISOString(),
        difficulty,
      });
      await onRefresh();
    } catch (e) {
      onError(formatApiError(e));
    }
  }

  return (
    <div className="space-y-4">
      <Card variant="farm">
        <h3 className="font-bold">Calving countdown</h3>
        <ul className="mt-2 space-y-2">
          {gestations.map((g) => (
            <li
              key={g.id}
              className="flex items-center justify-between rounded-farm border border-farm-border p-3"
            >
              <div>
                <p className="font-semibold">Cow #{g.cow_id}</p>
                <p className="text-sm">Expected {g.expected_calving_date}</p>
              </div>
              <span
                className={`rounded-full px-3 py-1 text-sm font-bold ${
                  g.days_until_calving <= 7 ? "bg-farm-danger/15 text-farm-danger" : "bg-farm-primary/10"
                }`}
              >
                {g.days_until_calving}d
              </span>
            </li>
          ))}
          {gestations.length === 0 ? (
            <p className="text-sm text-farm-text-muted">No active gestations.</p>
          ) : null}
        </ul>
      </Card>

      <Card variant="farm">
        <h3 className="font-bold">Record calving event</h3>
        <div className="mt-3 space-y-3">
          <Field variant="farm" label="Cow (dam)">
            <SelectInput variant="farm" value={cowId} onChange={(e) => setCowId(e.target.value)}>
              <option value="">Select…</option>
              {cows.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field variant="farm" label="difficulty">
            <SelectInput
              variant="farm"
              value={difficulty}
              onChange={(e) => setDifficulty(e.target.value as "easy" | "assisted" | "veterinary")}
            >
              <option value="easy">easy</option>
              <option value="assisted">assisted</option>
              <option value="veterinary">veterinary</option>
            </SelectInput>
          </Field>
          <Button variant="farm" type="button" disabled={loading} onClick={() => void handleCalving()}>
            Record calving
          </Button>
        </div>
      </Card>
    </div>
  );
}

function LactationTab({
  cows,
  records,
  farmId,
  loading,
  onRefresh,
  onError,
}: {
  cows: Cow[];
  records: Awaited<ReturnType<import("@livestok/api").ReproductionResources["listLactationRecords"]>>["data"];
  farmId?: number;
  loading: boolean;
  onRefresh: () => Promise<void>;
  onError: (m: string | null) => void;
}) {
  const { reproduction } = useAuth();
  const [cowId, setCowId] = useState("");
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [yieldLiters, setYieldLiters] = useState("12");

  async function handleSave() {
    if (!cowId || !farmId) return;
    onError(null);
    try {
      await reproduction.createLactationRecord({
        cow_id: Number(cowId),
        farm_id: farmId,
        milking_date: date,
        yield_liters: Number(yieldLiters),
        source: "manual",
      });
      await onRefresh();
    } catch (e) {
      onError(formatApiError(e));
    }
  }

  return (
    <div className="space-y-4">
      <Card variant="farm">
        <h3 className="font-bold">Log milking</h3>
        <div className="mt-3 space-y-3">
          <Field variant="farm" label="Cow">
            <SelectInput variant="farm" value={cowId} onChange={(e) => setCowId(e.target.value)}>
              <option value="">Select…</option>
              {cows.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field variant="farm" label="milking_date">
            <TextInput variant="farm" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </Field>
          <Field variant="farm" label="yield_liters">
            <TextInput variant="farm" inputMode="decimal" value={yieldLiters} onChange={(e) => setYieldLiters(e.target.value)} />
          </Field>
          <Button variant="farm" type="button" disabled={loading} onClick={() => void handleSave()}>
            Save lactation record
          </Button>
        </div>
      </Card>

      <Card variant="farm">
        <h3 className="font-bold">Recent records</h3>
        <ul className="mt-2 space-y-1 text-sm">
          {records.slice(0, 10).map((r) => (
            <li key={r.id}>
              Cow #{r.cow_id}: {r.yield_liters} L on {r.milking_date}
            </li>
          ))}
        </ul>
      </Card>
    </div>
  );
}

function DryOffTab({
  schedules,
  gestations,
  onRefresh,
  onError,
}: {
  schedules: Awaited<ReturnType<import("@livestok/api").ReproductionResources["listDryOffSchedules"]>>["data"];
  gestations: Awaited<ReturnType<import("@livestok/api").ReproductionResources["listGestations"]>>["data"];
  onRefresh: () => Promise<void>;
  onError: (m: string | null) => void;
}) {
  const { reproduction } = useAuth();

  async function handleCreate(gestationId: number) {
    onError(null);
    try {
      await reproduction.createDryOffSchedule(gestationId);
      await onRefresh();
    } catch (e) {
      onError(formatApiError(e));
    }
  }

  return (
    <div className="space-y-4">
      <Card variant="farm">
        <h3 className="font-bold">Dry-off schedules</h3>
        <p className="text-sm text-farm-text-muted">
          scheduled_dry_off_date = expected_calving_date − 60 days (backend default).
        </p>
        <ul className="mt-2 space-y-2">
          {schedules.map((s) => (
            <li key={s.id} className="rounded-farm border border-farm-border p-3 text-sm">
              Cow #{s.cow_id} · {s.scheduled_dry_off_date} · {s.status}
            </li>
          ))}
          {schedules.length === 0 ? <p className="text-sm">No schedules yet.</p> : null}
        </ul>
      </Card>

      <Card variant="farm">
        <h3 className="font-bold">Create from gestation</h3>
        <ul className="mt-2 space-y-2">
          {gestations.map((g) => (
            <li key={g.id} className="flex items-center justify-between text-sm">
              <span>Gestation #{g.id} — cow #{g.cow_id}</span>
              <Button
                variant="farm"
                type="button"
                className="!min-h-10 text-xs"
                onClick={() => void handleCreate(g.id)}
              >
                Schedule dry-off
              </Button>
            </li>
          ))}
        </ul>
      </Card>
    </div>
  );
}
