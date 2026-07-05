import type { ConfirmedCaseRecord } from "@livestok/api";
import {
  Card,
  IconButton,
  ResponsiveDataList,
  ShieldOff,
  type DataColumn,
} from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { useAdminAuth } from "../context/AdminAuthContext";

function truncate(text: string, max = 80): string {
  if (text.length <= max) return text;
  return `${text.slice(0, max)}…`;
}

export function CaseMemoryPage() {
  const { admin } = useAdminAuth();
  const [cases, setCases] = useState<ConfirmedCaseRecord[]>([]);
  const [selected, setSelected] = useState<ConfirmedCaseRecord | null>(null);
  const [revokingId, setRevokingId] = useState<number | null>(null);
  const [error, setError] = useState("");

  const loadCases = useCallback(async () => {
    const { data } = await admin.listConfirmedCases({ limit: 200 });
    setCases(data);
    setSelected((prev) => (prev ? (data.find((c) => c.id === prev.id) ?? null) : null));
  }, [admin]);

  useEffect(() => {
    void loadCases().catch((err: unknown) => {
      setError(err instanceof Error ? err.message : "Failed to load cases");
    });
  }, [loadCases]);

  async function handleRevoke(record: ConfirmedCaseRecord) {
    const ok = window.confirm(
      `Revoke confirmation for case #${record.id}? It will no longer be reused in consult RAG until re-confirmed.`,
    );
    if (!ok) return;

    setRevokingId(record.id);
    setError("");
    try {
      await admin.revokeConfirmedCase(record.id);
      if (selected?.id === record.id) setSelected(null);
      await loadCases();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Revoke failed");
    } finally {
      setRevokingId(null);
    }
  }

  const columns: DataColumn<ConfirmedCaseRecord>[] = [
    { id: "farm", header: "Farm", cell: (c) => c.farm_name ?? `#${c.farm_id}` },
    {
      id: "cow",
      header: "Cow",
      cell: (c) => c.cow_name ?? c.cow_tag_id ?? `#${c.cow_id}`,
    },
    {
      id: "summary",
      header: "Situation",
      cell: (c) => truncate(c.situation_summary),
    },
    {
      id: "confirmed",
      header: "Confirmed",
      cell: (c) => new Date(c.confirmed_at).toLocaleString(),
    },
    {
      id: "actions",
      header: "Actions",
      mobileLabel: "Revoke",
      cell: (c) => (
        <IconButton
          variant="admin"
          label="Revoke confirmation"
          className="h-9 w-9"
          disabled={revokingId === c.id}
          onClick={(e) => {
            e.stopPropagation();
            void handleRevoke(c);
          }}
        >
          <ShieldOff size={18} aria-hidden />
        </IconButton>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Case memory QC</h2>
      <p className="text-sm text-admin-text-muted">
        Vet-confirmed cases in the RAG corpus. Revoking un-confirms a bad entry so it stops being
        reused in consult sessions. This is oversight only — cow consult stays in the Farm App.
      </p>

      {error ? <p className="text-sm text-admin-danger">{error}</p> : null}

      <ResponsiveDataList
        rows={cases}
        columns={columns}
        rowKey={(c) => c.id}
        onRowClick={setSelected}
        nonClickableColumnIds={["actions"]}
        emptyMessage="No confirmed cases in memory."
      />

      {selected ? (
        <Card variant="admin" className="space-y-3">
          <div className="flex flex-wrap items-start justify-between gap-2">
            <h3 className="text-lg font-semibold">Case #{selected.id} review</h3>
            <IconButton
              variant="admin"
              label="Revoke confirmation"
              className="h-10 w-10 shrink-0"
              disabled={revokingId === selected.id}
              onClick={() => void handleRevoke(selected)}
            >
              <ShieldOff size={20} aria-hidden />
            </IconButton>
          </div>
          <p className="text-xs text-admin-text-muted">
            {selected.farm_name ?? `Farm ${selected.farm_id}`} ·{" "}
            {selected.cow_name ?? selected.cow_tag_id ?? `Cow ${selected.cow_id}`} · Confirmed{" "}
            {new Date(selected.confirmed_at).toLocaleString()}
            {selected.confirmed_by_user_id != null
              ? ` by user #${selected.confirmed_by_user_id}`
              : ""}
          </p>
          <section>
            <h4 className="mb-1 text-sm font-semibold text-admin-text-muted">Situation summary</h4>
            <p className="whitespace-pre-wrap text-sm">{selected.situation_summary}</p>
          </section>
          {selected.assistant_answer ? (
            <section>
              <h4 className="mb-1 text-sm font-semibold text-admin-text-muted">Assistant answer</h4>
              <p className="whitespace-pre-wrap text-sm">{selected.assistant_answer}</p>
            </section>
          ) : null}
        </Card>
      ) : null}
    </div>
  );
}
