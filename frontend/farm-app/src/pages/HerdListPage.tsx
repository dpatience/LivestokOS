import type { Cow } from "@livestok/api";
import { Button, Field, SelectInput, TextInput } from "@livestok/ui";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { formatApiError, useAuth } from "../context/AuthContext";
import { filterCows, type HerdSortKey } from "../lib/herd-utils";

type SortKey = HerdSortKey;

export function HerdListPage() {
  const { resources } = useAuth();
  const [cows, setCows] = useState<Cow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [sortKey, setSortKey] = useState<SortKey>("name");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await resources.listCows({ limit: 200 });
      setCows(data);
    } catch (err) {
      setError(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [resources]);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = useMemo(
    () => filterCows(cows, { search, statusFilter, sortKey }),
    [cows, search, statusFilter, sortKey],
  );

  const statuses = useMemo(() => {
    const set = new Set(cows.map((c) => c.healthStatus));
    return ["all", ...Array.from(set).sort()];
  }, [cows]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h2 className="text-xl font-bold text-farm-text">Herd</h2>
        <Link
          to="/herd/new"
          className="tap-target inline-flex items-center justify-center rounded-farm bg-farm-primary px-4 text-farm-body font-semibold text-white"
        >
          + Add cow
        </Link>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        <Field variant="farm" label="Search">
          <TextInput
            variant="farm"
            placeholder="Name, breed, status…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </Field>
        <Field variant="farm" label="Status">
          <SelectInput
            variant="farm"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            {statuses.map((s) => (
              <option key={s} value={s}>
                {s === "all" ? "All statuses" : s}
              </option>
            ))}
          </SelectInput>
        </Field>
        <Field variant="farm" label="Sort by">
          <SelectInput
            variant="farm"
            value={sortKey}
            onChange={(e) => setSortKey(e.target.value as SortKey)}
          >
            <option value="name">Name</option>
            <option value="breed">Breed</option>
            <option value="age">Age</option>
            <option value="healthStatus">Health status</option>
          </SelectInput>
        </Field>
      </div>

      {error ? (
        <p className="text-sm text-farm-danger" role="alert">
          {error}
        </p>
      ) : null}

      {loading ? (
        <p className="text-farm-text-muted">Loading herd…</p>
      ) : filtered.length === 0 ? (
        <p className="text-farm-text-muted">No cows match your filters.</p>
      ) : (
        <ul className="space-y-2">
          {filtered.map((cow) => (
            <li key={cow.id}>
              <Link
                to={`/herd/${cow.id}`}
                className="tap-target block rounded-farm border border-farm-border bg-farm-surface-alt px-4 py-3"
              >
                <div className="flex items-center justify-between gap-2">
                  <div>
                    <p className="font-semibold text-farm-text">{cow.name}</p>
                    <p className="text-sm text-farm-text-muted">
                      {cow.breed} · {cow.age} yr · {cow.healthStatus}
                    </p>
                  </div>
                  <span className="text-farm-text-muted" aria-hidden>
                    ›
                  </span>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}

      <Button variant="farm" className="w-full !bg-farm-surface-alt !text-farm-text border border-farm-border" onClick={() => void load()}>
        Refresh
      </Button>
    </div>
  );
}
