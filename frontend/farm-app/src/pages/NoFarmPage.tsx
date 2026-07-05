import { Link } from "react-router-dom";
import { farmLinkPrimary, farmLinkSecondary } from "@livestok/ui";
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
        <Link to="/register" className={`${farmLinkPrimary} block py-3 text-center`}>
          Create farm account
        </Link>
        <button
          type="button"
          className={`${farmLinkSecondary} w-full py-3`}
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
