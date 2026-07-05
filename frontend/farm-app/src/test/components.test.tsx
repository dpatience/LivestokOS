import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { GrazingModePicker } from "../components/GrazingModePicker";

describe("GrazingModePicker", () => {
  it("renders all three grazing modes", () => {
    render(
      <GrazingModePicker value="pasture" onChange={() => undefined} />,
    );
    expect(screen.getByText("Pasture grazing")).toBeInTheDocument();
    expect(screen.getByText("Zero grazing (indoor)")).toBeInTheDocument();
    expect(screen.getByText("Mixed system")).toBeInTheDocument();
  });
});

describe("HerdListPage filters", () => {
  it("filters cows client-side", async () => {
    const { filterCows } = await import("../lib/herd-utils");
    const cows = [
      { id: 1, name: "Bessie", breed: "Ankole", age: 3, weight: 500, healthStatus: "healthy" },
      { id: 2, name: "Duke", breed: "Holstein", age: 5, weight: 500, healthStatus: "sick" },
    ];
    expect(filterCows(cows, { search: "duke", statusFilter: "all", sortKey: "name" })).toHaveLength(1);
  });
});
