import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryRouter } from "react-router-dom";
import { HomePage } from "../pages/HomePage";

vi.mock("../hooks/useGrazingCoachVisible", () => ({
  useGrazingCoachVisible: vi.fn(),
}));

vi.mock("../hooks/useAlerts", () => ({
  useAlerts: () => ({
    alerts: [
      {
        id: 1,
        type: "GRAZING_RECOMMENDATION",
        message: "Move to north paddock",
        is_resolved: false,
        severity: "info",
        priority: "low",
        cow_id: null,
        farm_id: 1,
        severity_score: 20,
        inserted_at: "2026-07-05T10:00:00Z",
      },
    ],
    loading: false,
    refresh: vi.fn(),
    resolve: vi.fn(),
  }),
}));

const pastureFarm = { id: 1, name: "Pasture Farm", location: "A", grazing_mode: "pasture" as const };
const zeroFarm = { id: 2, name: "Indoor Farm", location: "B", grazing_mode: "zero_grazing" as const };

vi.mock("../context/AuthContext", () => ({
  useAuth: vi.fn(),
  formatApiError: (e: unknown) => String(e),
}));

import { useAuth } from "../context/AuthContext";
import { useGrazingCoachVisible } from "../hooks/useGrazingCoachVisible";

describe("HomePage grazing coach", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    cleanup();
  });

  it("shows Grazing Coach for pasture farms from backend grazing_mode", () => {
    vi.mocked(useAuth).mockReturnValue({ farm: pastureFarm } as ReturnType<typeof useAuth>);
    vi.mocked(useGrazingCoachVisible).mockReturnValue(true);

    render(
      <MemoryRouter>
        <HomePage />
      </MemoryRouter>,
    );

    expect(screen.getByRole("heading", { name: "Grazing Coach" })).toBeInTheDocument();
  });

  it("entirely omits Grazing Coach for zero_grazing farms", () => {
    vi.mocked(useAuth).mockReturnValue({ farm: zeroFarm } as ReturnType<typeof useAuth>);
    vi.mocked(useGrazingCoachVisible).mockReturnValue(false);

    render(
      <MemoryRouter>
        <HomePage />
      </MemoryRouter>,
    );

    expect(screen.queryByRole("heading", { name: "Grazing Coach" })).not.toBeInTheDocument();
    expect(screen.getByText(/Grazing Coach is not shown/)).toBeInTheDocument();
  });
});
