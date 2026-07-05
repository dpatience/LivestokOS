import { renderHook } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useGrazingCoachVisible } from "../hooks/useGrazingCoachVisible";

const zeroFarm = { id: 2, name: "Indoor", location: "B", grazing_mode: "zero_grazing" as const };

vi.mock("../context/AuthContext", () => ({
  useAuth: vi.fn(),
}));

import { useAuth } from "../context/AuthContext";

describe("useGrazingCoachVisible", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns false when backend grazing_mode is zero_grazing", () => {
    vi.mocked(useAuth).mockReturnValue({ farm: zeroFarm } as ReturnType<typeof useAuth>);
    const { result } = renderHook(() => useGrazingCoachVisible());
    expect(result.current).toBe(false);
  });
});
