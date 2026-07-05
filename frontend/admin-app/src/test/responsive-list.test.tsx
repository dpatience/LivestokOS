import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ResponsiveDataList } from "@livestok/ui";

describe("ResponsiveDataList", () => {
  it("renders stacked mobile cards and desktop table markup", () => {
    render(
      <ResponsiveDataList
        rows={[{ id: 1, name: "Farm A" }]}
        rowKey={(r) => r.id}
        columns={[
          { id: "name", header: "Farm", cell: (r) => r.name },
          { id: "id", header: "ID", cell: (r) => r.id },
        ]}
      />,
    );

    expect(screen.getByRole("table")).toBeInTheDocument();
    expect(screen.getAllByText("Farm A").length).toBeGreaterThanOrEqual(1);
    expect(document.querySelector("ul.md\\:hidden")).toBeTruthy();
  });
});
