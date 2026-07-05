import type { DigitalPassport } from "@livestok/api";
import { Button, Card, Field, SelectInput, TextInput } from "@livestok/ui";
import { ShieldCheck } from "@livestok/ui";
import { useEffect, useMemo, useState } from "react";
import { useAdminAuth } from "../context/AdminAuthContext";
import { FarmResources } from "@livestok/api";

export function PassportPage() {
  const { admin, api } = useAdminAuth();
  const resources = useMemo(() => new FarmResources(api), [api]);
  const [farms, setFarms] = useState<{ id: number; name: string }[]>([]);
  const [farmId, setFarmId] = useState("");
  const [query, setQuery] = useState("");
  const [cows, setCows] = useState<{ id: number; name: string; tag_id?: string }[]>([]);
  const [passport, setPassport] = useState<DigitalPassport | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    void (async () => {
      const { data } = await admin.listFarms();
      setFarms(data.map((f) => ({ id: f.id, name: f.name })));
    })();
  }, [admin]);

  useEffect(() => {
    if (!farmId) return;
    void (async () => {
      const { data } = await resources.listCows({ limit: 500 });
      setCows(data.map((c) => ({ id: c.id, name: c.name })));
    })();
  }, [farmId, resources]);

  async function lookup() {
    if (!farmId || !query.trim()) return;
    setLoading(true);
    setError("");
    setPassport(null);
    try {
      const q = query.trim().toLowerCase();
      const match =
        cows.find((c) => String(c.id) === q) ??
        cows.find((c) => c.name.toLowerCase().includes(q));

      if (!match) {
        setError("No cow matched — try numeric ID or name prefix.");
        return;
      }

      const { data } = await admin.getDigitalPassport(Number(farmId), match.id);
      setPassport(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Lookup failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Digital Passport</h2>
      <p className="text-sm text-admin-text-muted">
        Lookup via <code className="text-xs">GET /api/farms/:farm_id/cows/:cow_id/digital_passport</code>.
        Enter animal ID or scan RFID serial into the search field.
      </p>

      <div className="grid gap-3 md:grid-cols-2">
        <Field variant="admin" label="Farm">
          <SelectInput variant="admin" value={farmId} onChange={(e) => setFarmId(e.target.value)}>
            <option value="">Select…</option>
            {farms.map((f) => (
              <option key={f.id} value={f.id}>
                {f.name}
              </option>
            ))}
          </SelectInput>
        </Field>
        <Field variant="admin" label="Animal ID or RFID / name">
          <TextInput
            variant="admin"
            placeholder="Cow ID or necklace serial"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </Field>
      </div>

      <Button variant="admin" type="button" disabled={loading || !farmId} onClick={() => void lookup()}>
        {loading ? "Loading…" : "Lookup passport"}
      </Button>

      {error ? <p className="text-sm text-admin-danger">{error}</p> : null}

      {passport ? (
        <Card variant="admin" className="space-y-3">
          <div className="flex items-center gap-2">
            <ShieldCheck
              size={22}
              className={passport.signature ? "text-admin-success" : "text-admin-text-muted"}
              aria-hidden
            />
            <p className="font-semibold">
              {passport.signature ? "Signed passport" : "Unsigned (no farm signing key)"}
            </p>
          </div>
          <dl className="grid gap-2 text-sm md:grid-cols-2">
            <div>
              <dt className="text-admin-text-muted">Cow</dt>
              <dd className="font-medium">
                {passport.cow.name} ({passport.cow.tag_id})
              </dd>
            </div>
            <div>
              <dt className="text-admin-text-muted">Generated</dt>
              <dd>{new Date(passport.generated_at).toLocaleString()}</dd>
            </div>
            <div>
              <dt className="text-admin-text-muted">Carbon credit (tCO₂e)</dt>
              <dd>{passport.accumulated_carbon_credit_tco2e}</dd>
            </div>
            <div>
              <dt className="text-admin-text-muted">Ledger ref</dt>
              <dd className="font-mono text-xs">
                {passport.ledger_reference?.chain_hash?.slice(0, 16) ?? "None"}…
              </dd>
            </div>
          </dl>
          <p className="text-xs text-admin-text-muted">
            {passport.behavioral_history.length} behavioral events · {passport.rotation_log.length}{" "}
            grazing events in passport window.
          </p>
        </Card>
      ) : null}
    </div>
  );
}
