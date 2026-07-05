import type { JwtClaims } from "./types";

export function decodeJwtPayload(token: string): JwtClaims | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = atob(payload);
    return JSON.parse(json) as JwtClaims;
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string, skewSeconds = 30): boolean {
  const claims = decodeJwtPayload(token);
  if (!claims?.exp) return false;
  return Date.now() / 1000 >= claims.exp - skewSeconds;
}

/**
 * JWT storage: localStorage per app.
 *
 * Trade-off (explicit):
 * - localStorage survives PWA restarts and page reloads (required for field use).
 * - XSS can exfiltrate the token; mitigated by strict CSP and avoiding unsanitized HTML.
 * - httpOnly cookies would be safer but require a backend cookie proxy (not implemented).
 * - Memory-only storage was rejected: unusable for installed PWAs after restart.
 *
 * No refresh endpoint exists on the backend — on 401, callers must re-login.
 */
export class TokenStorage {
  constructor(private readonly storageKey: string) {}

  get(): string | null {
    try {
      return localStorage.getItem(this.storageKey);
    } catch {
      return null;
    }
  }

  set(token: string): void {
    localStorage.setItem(this.storageKey, token);
  }

  clear(): void {
    localStorage.removeItem(this.storageKey);
  }

  getClaims(): JwtClaims | null {
    const token = this.get();
    if (!token) return null;
    if (isTokenExpired(token)) {
      this.clear();
      return null;
    }
    return decodeJwtPayload(token);
  }
}

export const FARM_TOKEN_KEY = "livestok_farm_token";
export const ADMIN_TOKEN_KEY = "livestok_admin_token";

export const farmTokenStorage = new TokenStorage(FARM_TOKEN_KEY);
export const adminTokenStorage = new TokenStorage(ADMIN_TOKEN_KEY);
