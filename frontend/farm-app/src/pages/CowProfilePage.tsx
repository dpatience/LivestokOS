import type { Cow } from "@livestok/api";
import { Bot, Button, Card, ChevronLeft, farmCardRow, farmLinkInline, farmLinkPrimary } from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { formatApiError, useAuth } from "../context/AuthContext";

export function CowProfilePage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { resources } = useAuth();
  const [cow, setCow] = useState<Cow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError("");
    try {
      const { data } = await resources.getCow(Number(id));
      setCow(data);
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [id, resources]);

  useEffect(() => {
    void load();
  }, [load]);

  async function handleDelete() {
    if (!id || !confirm("Remove this cow from the herd?")) return;
    setDeleting(true);
    try {
      await resources.deleteCow(Number(id));
      navigate("/herd");
    } catch (err) {
      setError(formatApiError(err));
      setDeleting(false);
    }
  }

  if (loading) return <p className="text-farm-text-muted">Loading…</p>;
  if (!cow) return <p className="text-farm-danger">{error || "Cow not found"}</p>;

  return (
    <div className="space-y-4">
      <Link to="/herd" className={`inline-flex items-center gap-1 text-sm ${farmLinkInline}`}>
        <ChevronLeft size={16} aria-hidden />
        Back to herd
      </Link>

      <Card variant="farm">
        <h2 className="text-2xl font-bold text-farm-text">{cow.name}</h2>
        <dl className="mt-4 grid gap-3 text-farm-body">
          <div>
            <dt className="text-sm text-farm-text-muted">Breed</dt>
            <dd className="font-semibold">{cow.breed}</dd>
          </div>
          <div>
            <dt className="text-sm text-farm-text-muted">Age</dt>
            <dd className="font-semibold">{cow.age} years</dd>
          </div>
          <div>
            <dt className="text-sm text-farm-text-muted">Health status</dt>
            <dd className="font-semibold capitalize">{cow.healthStatus}</dd>
          </div>
          <div>
            <dt className="text-sm text-farm-text-muted">Weight (API placeholder)</dt>
            <dd className="font-semibold">{cow.weight} kg</dd>
          </div>
        </dl>
        <p className="mt-3 text-xs text-farm-text-muted">
          Tag ID, birth date, and sex are stored server-side but not exposed in CowJSON yet.
        </p>
      </Card>

      {error ? (
        <p className="text-sm text-farm-danger" role="alert">
          {error}
        </p>
      ) : null}

      <div className="grid gap-2">
        <Link
          to={`/consult?cow_id=${cow.id}`}
          className={`${farmCardRow} flex items-center justify-center gap-2 border-2 border-farm-primary bg-farm-primary/10 py-3 text-center font-semibold text-farm-primary`}
        >
          <Bot size={20} aria-hidden />
          AI consult about {cow.name}
        </Link>
        <Link to={`/herd/${cow.id}/edit`} className={`${farmLinkPrimary} block py-3 text-center`}>
          Edit cow
        </Link>
        <Button
          variant="farm"
          className="w-full !bg-farm-danger hover:opacity-90"
          disabled={deleting}
          onClick={() => void handleDelete()}
        >
          {deleting ? "Removing…" : "Remove cow"}
        </Button>
      </div>
    </div>
  );
}
