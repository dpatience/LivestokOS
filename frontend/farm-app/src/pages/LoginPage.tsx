import { Button, Field, TextInput } from "@livestok/ui";
import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { AuthLayout } from "../components/Layout";
import { formatApiError, useAuth } from "../context/AuthContext";

export function LoginPage() {
  const { login, loading, user } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  if (user) return <Navigate to="/" replace />;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    try {
      await login(email, password);
      navigate("/");
    } catch (err) {
      setError(formatApiError(err));
    }
  }

  return (
    <AuthLayout title="Sign in">
      <form className="mx-auto max-w-md space-y-4" onSubmit={(e) => void handleSubmit(e)}>
        <Field variant="farm" label="Email">
          <TextInput
            variant="farm"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Field>
        <Field variant="farm" label="Password">
          <TextInput
            variant="farm"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </Field>
        {error ? (
          <p className="text-sm text-farm-danger" role="alert">
            {error}
          </p>
        ) : null}
        <Button variant="farm" type="submit" className="w-full" disabled={loading}>
          {loading ? "Signing in…" : "Sign in"}
        </Button>
        <p className="text-center text-sm text-farm-text-muted">
          New farmer?{" "}
          <Link to="/register" className="font-semibold text-farm-primary underline">
            Create account
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
