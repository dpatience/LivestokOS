import { useEffect } from "react";
import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export function RequireAuth() {
  const { user, farm, refreshFarm } = useAuth();
  const location = useLocation();

  useEffect(() => {
    if (user?.farm_id && !farm) {
      void refreshFarm();
    }
  }, [user, farm, refreshFarm]);

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (!user.farm_id && location.pathname !== "/setup") {
    return <Navigate to="/setup" replace />;
  }

  return <Outlet />;
}
