import { Link } from "react-router-dom";
import { AuthLayout } from "../components/Layout";
import { useAuth } from "../context/AuthContext";

/**
 * Shown when JWT has no farm_id. Backend has no endpoint to assign an existing
 * user to a farm after registration — farm creation is bundled in POST /api/register.
 */
export function NoFarmPage() {
  const { logout } = useAuth();

  return (
    <AuthLayout title="No farm assigned">
      <div className="mx-auto max-w-md space-y-4 text-farm-body">
        <p className="text-farm-text-muted">
          Your account is not linked to a farm. New farmers should use registration, which
          creates your farm and links it in one step.
        </p>
        <Link
          to="/register"
          className="tap-target block rounded-farm bg-farm-primary px-4 py-3 text-center font-semibold text-white"
        >
          Create farm account
        </Link>
        <button
          type="button"
          className="tap-target w-full rounded-farm border border-farm-border px-4 py-3 font-semibold"
          onClick={() => {
            logout();
            window.location.href = "/login";
          }}
        >
          Sign out
        </button>
      </div>
    </AuthLayout>
  );
}
