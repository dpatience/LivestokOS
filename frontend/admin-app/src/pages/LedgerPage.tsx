import type { FarmLedger, LedgerEntry } from "@livestok/api";
import { Card, Field, ResponsiveDataList, SelectInput, StatusIndicator, type DataColumn } from "@livestok/ui";
import { Shield, ShieldAlert, ShieldCheck } from "@livestok/ui";
import { useEffect, useState } from "react";
import { useAdminAuth } from "../context/AdminAuthContext";

function chainIndicator(status: FarmLedger["chain_status"]) {
  switch (status) {
    case "valid":
      return (
        <StatusIndicator tone="success" icon={<ShieldCheck size={18} />} label="Chain valid" />
      );
    case "broken":
      return (
        <StatusIndicator tone="danger" icon={<ShieldAlert size={18} />} label="Chain broken" />
      );
    default:
      return <StatusIndicator tone="muted" icon={<Shield size={18} />} label="Empty chain" />;
  }
}

export function LedgerPage() {
  const { admin } = useAdminAuth();
  const [farms, setFarms] = useState<{ id: number; name: string }[]>([]);
  const [farmId, setFarmId] = useState("");
  const [ledger, setLedger] = useState<FarmLedger | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    void (async () => {
      const { data } = await admin.listFarms();
      setFarms(data.map((f) => ({ id: f.id, name: f.name })));
    })();
  }, [admin]);

  async function loadLedger(id: number) {
    setLoading(true);
    const { data } = await admin.getFarmLedger(id);
    setLedger(data);
    setLoading(false);
  }

  const columns: DataColumn<LedgerEntry>[] = [
    { id: "type", header: "Type", cell: (e) => e.record_type },
    { id: "record", header: "Record ID", cell: (e) => String(e.record_id) },
    {
      id: "hash",
      header: "Chain hash",
      cell: (e) => (
        <span className="font-mono text-xs">{e.chain_hash.slice(0, 12)}…</span>
      ),
    },
    {
      id: "at",
      header: "Inserted",
      cell: (e) => new Date(e.inserted_at).toLocaleString(),
    },
  ];

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Carbon ledger audit</h2>
      <p className="text-sm text-admin-text-muted">
        Read-only view of append-only hash-chain entries via{" "}
        <code className="text-xs">GET /api/admin/farms/:id/ledger</code> (CarbonLedger.verify_chain/1).
      </p>

      <Field variant="admin" label="Farm">
        <SelectInput
          variant="admin"
          value={farmId}
          onChange={(e) => {
            setFarmId(e.target.value);
            if (e.target.value) void loadLedger(Number(e.target.value));
          }}
        >
          <option value="">Select farm…</option>
          {farms.map((f) => (
            <option key={f.id} value={f.id}>
              {f.name}
            </option>
          ))}
        </SelectInput>
      </Field>

      {loading ? <p className="text-sm">Loading ledger…</p> : null}

      {ledger ? (
        <>
          <Card variant="admin">{chainIndicator(ledger.chain_status)}</Card>
          <ResponsiveDataList
            rows={ledger.entries}
            columns={columns}
            rowKey={(e) => e.id}
            emptyMessage="No ledger entries for this farm."
          />
        </>
      ) : null}
    </div>
  );
}
