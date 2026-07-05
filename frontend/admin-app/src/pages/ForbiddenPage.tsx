import { Card, adminLinkInline } from "@livestok/ui";
import { Link } from "react-router-dom";

export function ForbiddenPage() {
  return (
    <Card variant="admin">
      <h2 className="text-lg font-bold">Access denied</h2>
      <p className="mt-2 text-sm text-admin-text-muted">
        Your account does not have the <strong>super_admin</strong> role required for cross-farm
        admin endpoints. The backend returns 403 on /api/admin/* for other roles — this page is a
        UX guard only, not a security boundary.
      </p>
      <Link to="/login" className={`mt-4 inline-block ${adminLinkInline}`}>
        Sign in with a different account
      </Link>
    </Card>
  );
}
