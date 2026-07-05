import { Navigate, Outlet } from "react-router-dom";
import { isSuperAdmin, useAdminAuth } from "../context/AdminAuthContext";

/**
 * UX convenience only — backend AdminController.require_admin/1 enforces
 * `user.role == "super_admin"` and returns 403 otherwise. Do not rely on
 * this guard for security.
 */
export function RequireSuperAdmin() {
  const { user } = useAdminAuth();

  if (!user) return <Navigate to="/login" replace />;
  if (!isSuperAdmin(user.role)) return <Navigate to="/forbidden" replace />;
  return <Outlet />;
}
