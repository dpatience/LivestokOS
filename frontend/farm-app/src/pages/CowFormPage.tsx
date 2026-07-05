import { Button, Card, Field, SelectInput, TextInput } from "@livestok/ui";
import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { formatApiError, useAuth } from "../context/AuthContext";

const STATUS_OPTIONS = ["healthy", "sick", "quarantine", "dry"];

export function CowFormPage() {
  const { id } = useParams();
  const isEdit = Boolean(id);
  const navigate = useNavigate();
  const { user, resources } = useAuth();

  const [tagId, setTagId] = useState("");
  const [name, setName] = useState("");
  const [breed, setBreed] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [status, setStatus] = useState("healthy");
  const [sex, setSex] = useState<"male" | "female" | "unknown">("unknown");
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!isEdit || !id) return;
    void (async () => {
      setLoading(true);
      try {
        const { data } = await resources.getCow(Number(id));
        setName(data.name);
        setBreed(data.breed);
        setStatus(data.healthStatus);
        // Backend gap: CowJSON omits tag_id, birth_date, sex on read.
      } catch (err) {
        setError(formatApiError(err));
      } finally {
        setLoading(false);
      }
    })();
  }, [id, isEdit, resources]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!user?.farm_id) {
      setError("No farm assigned to your account.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const payload = {
        tag_id: tagId,
        name,
        breed,
        birth_date: birthDate,
        status,
        sex,
        farm_id: user.farm_id,
      };
      if (isEdit && id) {
        await resources.updateCow(Number(id), payload);
        navigate(`/herd/${id}`);
      } else {
        const { data } = await resources.createCow(payload);
        navigate(`/herd/${data.id}`);
      }
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <p className="text-farm-text-muted">Loading…</p>;

  return (
    <div className="mx-auto max-w-lg space-y-4">
      <h2 className="text-xl font-bold">{isEdit ? "Edit cow" : "Register new cow"}</h2>

      {isEdit ? (
        <Card variant="farm" className="text-sm text-farm-text-muted">
          Backend note: tag ID, birth date, and sex are not returned by GET /api/cows/:id
          (CowJSON gap). Re-enter them below if you need to update those fields.
        </Card>
      ) : null}

      <form className="space-y-4" onSubmit={(e) => void handleSubmit(e)}>
        <Field variant="farm" label="Tag ID">
          <TextInput variant="farm" required value={tagId} onChange={(e) => setTagId(e.target.value)} placeholder="COW-8842" />
        </Field>
        <Field variant="farm" label="Name">
          <TextInput variant="farm" required value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field variant="farm" label="Breed">
          <TextInput variant="farm" required value={breed} onChange={(e) => setBreed(e.target.value)} />
        </Field>
        <Field variant="farm" label="Birth date">
          <TextInput variant="farm" type="date" required value={birthDate} onChange={(e) => setBirthDate(e.target.value)} />
        </Field>
        <Field variant="farm" label="Health status">
          <SelectInput variant="farm" value={status} onChange={(e) => setStatus(e.target.value)}>
            {STATUS_OPTIONS.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </SelectInput>
        </Field>
        <Field variant="farm" label="Sex">
          <SelectInput variant="farm" value={sex} onChange={(e) => setSex(e.target.value as typeof sex)}>
            <option value="unknown">Unknown</option>
            <option value="female">Female</option>
            <option value="male">Male</option>
          </SelectInput>
        </Field>

        {error ? (
          <p className="text-sm text-farm-danger" role="alert">
            {error}
          </p>
        ) : null}

        <div className="flex gap-2">
          <Button variant="farm" type="submit" className="flex-1" disabled={saving}>
            {saving ? "Saving…" : isEdit ? "Save changes" : "Add cow"}
          </Button>
          <Link
            to={isEdit && id ? `/herd/${id}` : "/herd"}
            className="tap-target inline-flex flex-1 items-center justify-center rounded-farm border border-farm-border px-4 text-center font-semibold"
          >
            Cancel
          </Link>
        </div>
      </form>
    </div>
  );
}
