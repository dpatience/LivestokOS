import {
  ApiClient,
  adminTokenStorage,
  getRealtimeStatus,
  type AuthUser,
} from "@livestok/api";
import { AppShell, Button } from "@livestok/ui";
import { useCallback, useMemo, useState } from "react";

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000/api";

export default function App() {
  const [user, setUser] = useState<AuthUser | null>(() => {
    const claims = adminTokenStorage.getClaims();
    if (!claims) return null;
    return {
      id: Number(claims.sub),
      email: claims.email,
      name: claims.name,
      role: claims.role,
      farm_id: claims.farm_id,
    };
  });
  const [status, setStatus] = useState<string>("Ready");
  const [loading, setLoading] = useState(false);

  const api = useMemo(
    () =>
      new ApiClient({
        baseUrl: API_BASE,
        tokenStorage: adminTokenStorage,
        onUnauthorized: () => setUser(null),
      }),
    [],
  );

  const realtime = useMemo(() => getRealtimeStatus(API_BASE), []);

  const checkHealth = useCallback(async () => {
    setLoading(true);
    setStatus("Checking API…");
    try {
      const health = await api.health();
      setStatus(`API health: ${health.status ?? "ok"}`);
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Health check failed");
    } finally {
      setLoading(false);
    }
  }, [api]);

  return (
    <AppShell variant="admin" title="LivestokOS Admin">
      <div className="space-y-4 text-admin-body">
        <p className="text-admin-text-muted">
          Administration PWA scaffold. Cross-farm views require{" "}
          <code className="text-admin-text">super_admin</code> role (enforced server-side).
        </p>

        {user ? (
          <div className="rounded-admin border border-admin-border bg-admin-surface-alt p-4">
            <p className="font-semibold text-admin-text">{user.name}</p>
            <p className="text-admin-text-muted">{user.email}</p>
            <p className="text-admin-text-muted">
              Role: {user.role} · Farm: {user.farm_id ?? "none"}
            </p>
            <Button
              variant="admin"
              className="mt-3"
              onClick={() => {
                api.logout();
                setUser(null);
              }}
            >
              Sign out
            </Button>
          </div>
        ) : (
          <p className="text-admin-text-muted">
            Not signed in. Login screen comes in the next stage.
          </p>
        )}

        <Button variant="admin" disabled={loading} onClick={() => void checkHealth()}>
          Check API health
        </Button>

        <p className="text-sm text-admin-text-muted" role="status">
          {status}
        </p>

        <div className="rounded-admin border border-admin-border p-4 text-sm text-admin-text-muted">
          <p className="font-semibold text-admin-text">Real-time</p>
          <p>
            {realtime.available
              ? `Socket: ${realtime.socketUrl}`
              : realtime.reason}
          </p>
        </div>
      </div>
    </AppShell>
  );
}
