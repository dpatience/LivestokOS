import { ApiError, type AuthResponse, type LoginPayload, type RegisterPayload } from "./types";
import type { TokenStorage } from "./auth";

export interface ApiClientOptions {
  baseUrl: string;
  tokenStorage: TokenStorage;
  onUnauthorized?: () => void;
}

export class ApiClient {
  readonly baseUrl: string;
  private readonly tokenStorage: TokenStorage;
  private readonly onUnauthorized?: () => void;

  constructor(options: ApiClientOptions) {
    this.baseUrl = options.baseUrl.replace(/\/$/, "");
    this.tokenStorage = options.tokenStorage;
    this.onUnauthorized = options.onUnauthorized;
  }

  get token(): string | null {
    return this.tokenStorage.get();
  }

  async login(payload: LoginPayload): Promise<AuthResponse> {
    const response = await this.request<AuthResponse>("/login", {
      method: "POST",
      body: JSON.stringify(payload),
      auth: false,
    });
    this.tokenStorage.set(response.token);
    return response;
  }

  async register(payload: RegisterPayload): Promise<AuthResponse> {
    const response = await this.request<AuthResponse>("/register", {
      method: "POST",
      body: JSON.stringify(payload),
      auth: false,
    });
    this.tokenStorage.set(response.token);
    return response;
  }

  logout(): void {
    this.tokenStorage.clear();
  }

  async health(): Promise<{ status: string }> {
    return this.request<{ status: string }>("/health", { auth: false });
  }

  async request<T>(
    path: string,
    options: RequestInit & { auth?: boolean } = {},
  ): Promise<T> {
    const { auth = true, ...init } = options;
    const headers = new Headers(init.headers);
    headers.set("Accept", "application/json");
    if (init.body && !headers.has("Content-Type")) {
      headers.set("Content-Type", "application/json");
    }

    if (auth) {
      const token = this.tokenStorage.get();
      if (!token) {
        this.onUnauthorized?.();
        throw new ApiError("Not authenticated", 401);
      }
      headers.set("Authorization", `Bearer ${token}`);
    }

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers,
    });

    if (response.status === 401 && auth) {
      this.tokenStorage.clear();
      this.onUnauthorized?.();
      throw new ApiError("Unauthorized", 401);
    }

    const text = await response.text();
    const body = text ? (JSON.parse(text) as unknown) : null;

    if (!response.ok) {
      throw new ApiError(
        `Request failed: ${response.status}`,
        response.status,
        body as { error?: string; errors?: Record<string, string[]> },
      );
    }

    if (response.status === 204 || body === null) {
      return undefined as T;
    }

    return body as T;
  }
}
