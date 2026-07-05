import { useState } from "react";
import { AppShell, BottomNav, Button, Field, NavItem, TextInput } from "@livestok/ui";
import { Activity, BookOpen, Home, LogOut, Radio, RefreshCw, ShieldCheck } from "@livestok/ui";
import { Outlet, useNavigate } from "react-router-dom";
import { isSuperAdmin, useAdminAuth } from "../context/AdminAuthContext";

export function AdminLayout() {
  const { user, logout } = useAdminAuth();
  const navigate = useNavigate();

  return (
    <AppShell
      variant="admin"
      title={`LivestokOS Admin · ${user?.name ?? ""}`}
      nav={
        <BottomNav variant="admin">
          <NavItem to="/" end icon={<Home size={20} />} label="Farms" />
          <NavItem to="/fleet" icon={<Radio size={20} />} label="Fleet" />
          <NavItem to="/passport" icon={<BookOpen size={20} />} label="Passport" />
          <NavItem to="/ledger" icon={<Activity size={20} />} label="Ledger" />
          <NavItem to="/ai/cases" icon={<ShieldCheck size={20} />} label="Cases" />
          <NavItem to="/ai/research" icon={<RefreshCw size={20} />} label="Corpus" />
          <button
            type="button"
            className="tap-target flex flex-1 flex-col items-center justify-center gap-1 px-1 py-2 text-xs font-semibold text-admin-text-muted transition-colors hover:text-admin-danger focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-admin-accent active:scale-[0.98]"
            onClick={() => {
              logout();
              navigate("/login");
            }}
          >
            <LogOut size={20} aria-hidden />
            Sign out
          </button>
        </BottomNav>
      }
    >
      <Outlet />
    </AppShell>
  );
}

export function LoginPage() {
  const { login, user } = useAdminAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (user && isSuperAdmin(user.role)) {
    navigate("/", { replace: true });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await login(email, password);
      navigate("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AppShell variant="admin" title="Admin sign in">
      <form className="mx-auto max-w-md space-y-4" onSubmit={(e) => void handleSubmit(e)}>
        <p className="text-sm text-admin-text-muted">
          Cross-farm oversight requires <strong>super_admin</strong> role (validated server-side on
          every /api/admin/* request). There is no separate vet-admin role in the backend User
          schema.
        </p>
        <Field variant="admin" label="Email">
          <TextInput
            variant="admin"
            type="email"
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Field>
        <Field variant="admin" label="Password">
          <TextInput
            variant="admin"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </Field>
        {error ? <p className="text-sm text-admin-danger">{error}</p> : null}
        <Button variant="admin" type="submit" className="w-full" disabled={loading}>
          {loading ? "Signing in…" : "Sign in"}
        </Button>
      </form>
    </AppShell>
  );
}
