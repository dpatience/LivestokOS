import type { GrazingMode } from "@livestok/api";
import { Button, Field, TextInput, farmLinkInline } from "@livestok/ui";
import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { GrazingModePicker } from "../components/GrazingModePicker";
import { AuthLayout } from "../components/Layout";
import { formatApiError, useAuth } from "../context/AuthContext";

export function RegisterPage() {
  const { register, loading, user } = useAuth();
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [farmName, setFarmName] = useState("");
  const [location, setLocation] = useState("");
  const [grazingMode, setGrazingMode] = useState<GrazingMode>("pasture");
  const [error, setError] = useState("");

  if (user) return <Navigate to="/" replace />;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    try {
      await register({ name, email, password, farmName, location, grazingMode });
      navigate("/");
    } catch (err) {
      setError(formatApiError(err));
    }
  }

  return (
    <AuthLayout title="Create farm account">
      <form className="mx-auto max-w-lg space-y-5" onSubmit={(e) => void handleSubmit(e)}>
        <section className="space-y-3">
          <h2 className="text-farm-body font-bold text-farm-text">Your details</h2>
          <Field variant="farm" label="Full name">
            <TextInput variant="farm" required value={name} onChange={(e) => setName(e.target.value)} />
          </Field>
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
          <Field variant="farm" label="Password (min 6 characters)">
            <TextInput
              variant="farm"
              type="password"
              autoComplete="new-password"
              minLength={6}
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>
        </section>

        <section className="space-y-3">
          <h2 className="text-farm-body font-bold text-farm-text">Your farm</h2>
          <Field variant="farm" label="Farm name">
            <TextInput
              variant="farm"
              required
              value={farmName}
              onChange={(e) => setFarmName(e.target.value)}
            />
          </Field>
          <Field variant="farm" label="Location">
            <TextInput
              variant="farm"
              required
              placeholder="e.g. Kigali, Rwanda"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
            />
          </Field>
        </section>

        <GrazingModePicker value={grazingMode} onChange={setGrazingMode} />

        {error ? (
          <p className="text-sm text-farm-danger" role="alert">
            {error}
          </p>
        ) : null}

        <Button variant="farm" type="submit" className="w-full" disabled={loading}>
          {loading ? "Creating account…" : "Create account & farm"}
        </Button>

        <p className="text-center text-sm text-farm-text-muted">
          Already registered?{" "}
          <Link to="/login" className={farmLinkInline}>
            Sign in
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
