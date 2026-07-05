/**
 * Matches LivestokOsWeb.AuthJSON.user/1 response shape (verified).
 */
export interface AuthUser {
  id: number;
  email: string;
  name: string;
  role: "super_admin" | "farm_owner" | "farm_worker";
  farm_id: number | null;
}

export interface AuthResponse {
  data: AuthUser;
  token: string;
}

export interface LoginPayload {
  email: string;
  password: string;
}

export interface RegisterPayload {
  user: {
    email: string;
    name: string;
    password: string;
    role: AuthUser["role"];
  };
  farm?: {
    name: string;
    location?: string;
    grazing_mode?: string;
  };
}

export interface JwtClaims {
  sub: string;
  email: string;
  name: string;
  role: AuthUser["role"];
  farm_id: number | null;
  exp?: number;
  iat?: number;
}

export interface ApiErrorBody {
  error?: string;
  errors?: Record<string, string[]>;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public body?: ApiErrorBody,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export type RealtimeStatus =
  | { available: false; reason: string }
  | { available: true; socketUrl: string };

/**
 * Backend has no Phoenix Channels for JSON clients today — only LiveView at /live.
 * Do not wire phoenix.js until a UserSocket and topics are added server-side.
 */
export function getRealtimeStatus(_apiBaseUrl: string): RealtimeStatus {
  return {
    available: false,
    reason:
      "No Phoenix Channels exist yet (endpoint only mounts LiveView socket at /live). Use polling until backend adds topics.",
  };
}
