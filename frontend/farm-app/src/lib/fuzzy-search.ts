import type { Cow } from "@livestok/api";

/** Lightweight fuzzy match — no external dependency. */
export function fuzzyFilterCows(cows: Cow[], query: string, limit = 8): Cow[] {
  const q = query.trim().toLowerCase();
  if (!q) return cows.slice(0, limit);

  return cows
    .map((cow) => ({ cow, score: scoreCow(cow, q) }))
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((x) => x.cow);
}

function scoreCow(cow: Cow, q: string): number {
  const name = cow.name.toLowerCase();
  const breed = cow.breed.toLowerCase();
  const status = cow.healthStatus.toLowerCase();

  if (name.startsWith(q)) return 100;
  if (name.includes(q)) return 80;
  if (breed.includes(q)) return 60;
  if (status.includes(q)) return 40;
  if (subsequenceMatch(name, q)) return 30;
  return 0;
}

function subsequenceMatch(text: string, query: string): boolean {
  let ti = 0;
  for (const ch of query) {
    ti = text.indexOf(ch, ti);
    if (ti === -1) return false;
    ti += 1;
  }
  return true;
}
