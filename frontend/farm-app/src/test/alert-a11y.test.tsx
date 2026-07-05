import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AlertCard } from "../components/AlertCard";
import type { Alert } from "@livestok/api";

function mockAlert(overrides: Partial<Alert>): Alert {
  return {
    id: 1,
    type: "HEALTH_RISK",
    message: "Elevated temperature detected",
    is_resolved: false,
    severity: "warning",
    priority: "high",
    cow_id: 1,
    farm_id: 1,
    severity_score: 45,
    inserted_at: "2026-07-05T10:00:00Z",
    ...overrides,
  };
}

describe("AlertCard accessibility (non-color cues)", () => {
  it("urgent health alerts use diamond shape and descriptive aria-label", () => {
    const { container } = render(
      <AlertCard alert={mockAlert({ type: "HEALTH_RISK" })} />,
    );
    const article = screen.getByRole("article", { name: /health alert/i });
    expect(article).toHaveAttribute("data-visual-shape", "notched-urgent");
    expect(container.querySelector('[data-visual-shape="diamond"]')).toBeTruthy();
  });

  it("calving alerts expose calving label for assistive tech", () => {
    render(<AlertCard alert={mockAlert({ type: "CALVING_IMMINENT", severity_score: 100 })} />);
    expect(screen.getByRole("article", { name: /calving alert/i })).toBeInTheDocument();
  });

  it("grazing suggestions use pill shape and circle icon container", () => {
    const { container } = render(
      <AlertCard alert={mockAlert({ type: "GRAZING_RECOMMENDATION", severity_score: 20 })} />,
    );
    const article = screen.getByRole("article", { name: /grazing suggestion/i });
    expect(article).toHaveAttribute("data-visual-shape", "pill");
    expect(container.querySelector('[data-visual-shape="circle"]')).toBeTruthy();
  });

  it("urgent and grazing groups differ by shape attribute (colorblind-safe)", () => {
    const { container: urgentDom } = render(
      <AlertCard alert={mockAlert({ type: "HEALTH_RISK" })} />,
    );
    const { container: grazingDom } = render(
      <AlertCard alert={mockAlert({ type: "GRAZING_RECOMMENDATION", severity_score: 20 })} />,
    );
    expect(urgentDom.querySelector('[data-visual-shape="diamond"]')).toBeTruthy();
    expect(grazingDom.querySelector('[data-visual-shape="pill"]')).toBeTruthy();
    expect(urgentDom.querySelector('[data-visual-shape="pill"]')).toBeNull();
  });
});
