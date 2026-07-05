/** In-memory stale-while-revalidate cache for low-churn list endpoints only. */

export interface CacheMeta {
  fetchedAt: number;
  fromCache: boolean;
  isStale: boolean;
}

export interface CachedListResult<T> {
  data: T;
  meta: CacheMeta;
}

interface CacheEntry<T> {
  data: T;
  fetchedAt: number;
}

const store = new Map<string, CacheEntry<unknown>>();

export function clearResponseCache(prefix?: string): void {
  if (!prefix) {
    store.clear();
    return;
  }
  for (const key of store.keys()) {
    if (key.startsWith(prefix)) store.delete(key);
  }
}

/**
 * Fetches with optional TTL. Returns stale cached data immediately when fresh
 * fetch fails; marks `isStale` when age exceeds `ttlMs`.
 */
export async function fetchWithCache<T>(
  key: string,
  fetcher: () => Promise<T>,
  options: { ttlMs: number; forceRefresh?: boolean },
): Promise<CachedListResult<T>> {
  const now = Date.now();
  const existing = store.get(key) as CacheEntry<T> | undefined;

  if (!options.forceRefresh && existing && now - existing.fetchedAt < options.ttlMs) {
    return {
      data: existing.data,
      meta: { fetchedAt: existing.fetchedAt, fromCache: true, isStale: false },
    };
  }

  try {
    const data = await fetcher();
    const fetchedAt = Date.now();
    store.set(key, { data, fetchedAt });
    return {
      data,
      meta: { fetchedAt, fromCache: false, isStale: false },
    };
  } catch (err) {
    if (existing) {
      return {
        data: existing.data,
        meta: {
          fetchedAt: existing.fetchedAt,
          fromCache: true,
          isStale: true,
        },
      };
    }
    throw err;
  }
}
