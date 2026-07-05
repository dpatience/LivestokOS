import {
  AdminResources,
  ApiClient,
  adminTokenStorage,
  isSuperAdmin,
  type AuthUser,
} from "@livestok/api";
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000/api";

interface AdminAuthContextValue {
  user: AuthUser | null;
  api: ApiClient;
  admin: AdminResources;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AdminAuthContext = createContext<AdminAuthContextValue | null>(null);

function claimsToUser(claims: ReturnType<typeof adminTokenStorage.getClaims>): AuthUser | null {
  if (!claims) return null;
  return {
    id: Number(claims.sub),
    email: claims.email,
    name: claims.name,
    role: claims.role,
    farm_id: claims.farm_id,
  };
}

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => claimsToUser(adminTokenStorage.getClaims()));

  const api = useMemo(
    () =>
      new ApiClient({
        baseUrl: API_BASE,
        tokenStorage: adminTokenStorage,
        onUnauthorized: () => setUser(null),
      }),
    [],
  );

  const admin = useMemo(() => new AdminResources(api), [api]);

  const login = useCallback(
    async (email: string, password: string) => {
      const { data } = await api.login({ email, password });
      setUser(data);
    },
    [api],
  );

  const logout = useCallback(() => {
    api.logout();
    setUser(null);
  }, [api]);

  const value = useMemo(
    () => ({ user, api, admin, login, logout }),
    [user, api, admin, login, logout],
  );

  return <AdminAuthContext.Provider value={value}>{children}</AdminAuthContext.Provider>;
}

export function useAdminAuth() {
  const ctx = useContext(AdminAuthContext);
  if (!ctx) throw new Error("useAdminAuth must be used within AdminAuthProvider");
  return ctx;
}

export { isSuperAdmin };
