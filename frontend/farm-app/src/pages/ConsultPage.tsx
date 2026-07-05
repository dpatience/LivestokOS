import { Card } from "@livestok/ui";
import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { ConsultChat } from "../components/ConsultChat";
import { useAuth } from "../context/AuthContext";

export function ConsultPage() {
  const { resources } = useAuth();
  const [searchParams] = useSearchParams();
  const initialCowId = searchParams.get("cow_id");
  const [cowId, setCowId] = useState<number | null>(
    initialCowId ? Number(initialCowId) : null,
  );
  const [cows, setCows] = useState<{ id: number; name: string }[]>([]);

  useEffect(() => {
    void (async () => {
      const { data } = await resources.listCows({ limit: 200 });
      setCows(data.map((c) => ({ id: c.id, name: c.name })));
    })();
  }, [resources]);

  useEffect(() => {
    if (initialCowId) setCowId(Number(initialCowId));
  }, [initialCowId]);

  const cowName = cows.find((c) => c.id === cowId)?.name;

  return (
    <div className="space-y-3">
      <div>
        <h2 className="text-xl font-bold">AI vet consult</h2>
        <p className="text-sm text-farm-text-muted">
          Multi-turn consult scoped to one cow. Backend requires <code className="text-xs">cow_id</code>{" "}
          at session start — deep-link from any cow profile via{" "}
          <code className="text-xs">/consult?cow_id=…</code>
        </p>
      </div>

      <Card variant="farm" className="!p-3">
        <ConsultChat
          cowId={cowId}
          cowName={cowName}
          cows={cows}
          showCowPicker
          onCowChange={setCowId}
        />
      </Card>
    </div>
  );
}
