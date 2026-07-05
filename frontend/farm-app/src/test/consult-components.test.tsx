import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ConsultMessage, InsufficientDataPanel, ProvenanceBadges } from "../components/ConsultMessage";
import type { ConsultReply } from "@livestok/api";

describe("ConsultMessage provenance UI", () => {
  it("renders distinct provenance badges per source type", () => {
    render(
      <ProvenanceBadges
        attributions={[
          { source_type: "cow_own_data", count: 1 },
          { source_type: "research_corpus", count: 2 },
        ]}
      />,
    );
    expect(screen.getByText(/This cow's data/)).toBeInTheDocument();
    expect(screen.getByText(/Research citation ×2/)).toBeInTheDocument();
  });

  it("shows insufficient data panel distinctly from normal answers", () => {
    const reply: ConsultReply = {
      response: "The data needed to answer this question is not yet available in the system.",
      sources: [],
      insufficient_data: true,
      confirmed_case_reused: false,
      confirmed_case: null,
      recommended_next_steps: ["Perform physical examination"],
      attributions: [],
    };

    render(<InsufficientDataPanel reply={reply} />);
    expect(screen.getByRole("alert")).toHaveTextContent("Insufficient data");
    expect(screen.getByText("Perform physical examination")).toBeInTheDocument();
  });

  it("shows confirmed case banner with date", () => {
    const reply: ConsultReply = {
      response: "Similar confirmed case found:\n\nPrevious answer: rest",
      sources: [{ source_type: "cross_farm_pattern", data: {} }],
      insufficient_data: false,
      confirmed_case_reused: true,
      confirmed_case: {
        confirmed_at: "2026-03-15T10:00:00Z",
        situation_summary: "Low rumination post-calving",
      },
      recommended_next_steps: null,
      attributions: [{ source_type: "cross_farm_pattern", count: 1 }],
    };

    render(<ConsultMessage role="assistant" content={reply.response} reply={reply} />);
    expect(screen.getByRole("note")).toHaveTextContent(/vet-confirmed case from/);
    expect(screen.getByText(/Cross-farm pattern/)).toBeInTheDocument();
  });
});
