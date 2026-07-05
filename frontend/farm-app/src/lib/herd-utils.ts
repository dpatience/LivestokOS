import type { Cow } from "@livestok/api";

export type HerdSortKey = "name" | "breed" | "age" | "healthStatus";

export interface HerdFilterOptions {
  search: string;
  statusFilter: string;
  sortKey: HerdSortKey;
}

export function filterCows(cows: Cow[], opts: HerdFilterOptions): Cow[] {
  let list = cows;
  const q = opts.search.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.breed.toLowerCase().includes(q) ||
        c.healthStatus.toLowerCase().includes(q),
    );
  }
  if (opts.statusFilter !== "all") {
    list = list.filter((c) => c.healthStatus === opts.statusFilter);
  }
  return [...list].sort((a, b) => {
    const av = a[opts.sortKey];
    const bv = b[opts.sortKey];
    if (typeof av === "number" && typeof bv === "number") return av - bv;
    return String(av).localeCompare(String(bv));
  });
}
