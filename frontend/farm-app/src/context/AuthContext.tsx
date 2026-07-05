import {
  ApiClient,
  ApiError,
  FarmResources,
  farmTokenStorage,
  type AuthUser,
  type Farm,
  type GrazingMode,
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

interface AuthContextValue {
  user: AuthUser | null;
  farm: Farm | null;
  api: ApiClient;
  resources: FarmResources;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (payload: {
    name: string;
    email: string;
    password: string;
    farmName: string;
    location: string;
    grazingMode: GrazingMode;
  }) => Promise<void>;
  logout: () => void;
  refreshFarm: () => Promise<void>;
  setFarm: (farm: Farm | null) => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function claimsToUser(claims: ReturnType<typeof farmTokenStorage.getClaims>): AuthUser | null {
  if (!claims) return null;
  return {
    id: Number(claims.sub),
    email: claims.email,
    name: claims.name,
    role: claims.role,
    farm_id: claims.farm_id,
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => claimsToUser(farmTokenStorage.getClaims()));
  const [farm, setFarm] = useState<Farm | null>(null);
  const [loading, setLoading] = useState(false);

  const api = useMemo(
    () =>
      new ApiClient({
        baseUrl: API_BASE,
        tokenStorage: farmTokenStorage,
        onUnauthorized: () => {
          setUser(null);
          setFarm(null);
        },
      }),
    [],
  );

  const resources = useMemo(() => new FarmResources(api), [api]);

  const refreshFarm = useCallback(async () => {
    const current = claimsToUser(farmTokenStorage.getClaims());
    setUser(current);
    if (!current?.farm_id) {
      setFarm(null);
      return;
    }
    const { data } = await resources.getFarm(current.farm_id);
    setFarm(data);
  }, [resources]);

  const login = useCallback(
    async (email: string, password: string) => {
      setLoading(true);
      try {
        const { data } = await api.login({ email, password });
        setUser(data);
        if (data.farm_id) {
          const farmRes = await resources.getFarm(data.farm_id);
          setFarm(farmRes.data);
        } else {
          setFarm(null);
        }
      } finally {
        setLoading(false);
      }
    },
    [api, resources],
  );

  const register = useCallback(
    async (payload: {
      name: string;
      email: string;
      password: string;
      farmName: string;
      location: string;
      grazingMode: GrazingMode;
    }) => {
      setLoading(true);
      try {
        const { data } = await api.register({
          user: {
            email: payload.email,
            name: payload.name,
            password: payload.password,
            role: "farm_owner",
          },
          farm: {
            name: payload.farmName,
            location: payload.location,
            grazing_mode: payload.grazingMode,
          },
        });
        setUser(data);
        if (data.farm_id) {
          const farmRes = await resources.getFarm(data.farm_id);
          setFarm(farmRes.data);
        }
      } finally {
        setLoading(false);
      }
    },
    [api, resources],
  );

  const logout = useCallback(() => {
    api.logout();
    setUser(null);
    setFarm(null);
  }, [api]);

  const value = useMemo(
    () => ({
      user,
      farm,
      api,
      resources,
      loading,
      login,
      register,
      logout,
      refreshFarm,
      setFarm,
    }),
    [user, farm, api, resources, loading, login, register, logout, refreshFarm],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

export function formatApiError(err: unknown): string {
  if (err instanceof ApiError) {
    const fieldErrors = err.body?.errors;
    if (fieldErrors) {
      return Object.entries(fieldErrors)
        .flatMap(([k, msgs]) => msgs.map((m) => `${k}: ${m}`))
        .join("; ");
    }
    return err.body?.error ?? err.message;
  }
  if (err instanceof Error) return err.message;
  return "Something went wrong";
}
