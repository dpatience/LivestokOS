import type { Cow } from "@livestok/api";
import { Field, TextInput, farmCardRow } from "@livestok/ui";
import { useMemo, useState } from "react";
import { fuzzyFilterCows } from "../lib/fuzzy-search";
import type { IdentifiedCow } from "./NfcCowIdentify";

interface CowSearchPickerProps {
  cows: Cow[];
  onSelect: (cow: IdentifiedCow) => void;
}

export function CowSearchPicker({ cows, onSelect }: CowSearchPickerProps) {
  const [query, setQuery] = useState("");

  const results = useMemo(() => fuzzyFilterCows(cows, query), [cows, query]);

  return (
    <div className="space-y-2">
      <Field variant="farm" label="Search cow (name or breed)">
        <TextInput
          variant="farm"
          placeholder="Start typing…"
          value={query}
          autoComplete="off"
          onChange={(e) => setQuery(e.target.value)}
        />
      </Field>
      <ul className="space-y-1">
        {results.map((cow) => (
          <li key={cow.id}>
            <button
              type="button"
              className={`${farmCardRow} w-full text-left`}
              onClick={() => onSelect({ id: cow.id, name: cow.name, source: "search" })}
            >
              <p className="font-semibold text-farm-text">{cow.name}</p>
              <p className="text-sm text-farm-text-muted">
                {cow.breed} · {cow.healthStatus}
              </p>
            </button>
          </li>
        ))}
        {query && results.length === 0 ? (
          <li className="px-2 text-sm text-farm-text-muted">No cows match “{query}”</li>
        ) : null}
      </ul>
    </div>
  );
}
