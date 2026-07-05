import { describe, expect, it } from "vitest";
import {
  isConfirmedCaseReply,
  isInsufficientReply,
  sourceLabel,
  type ConsultReply,
} from "@livestok/api";

function mockReply(overrides: Partial<ConsultReply>): ConsultReply {
  return {
    response: "Normal answer",
    sources: [],
    insufficient_data: false,
    confirmed_case_reused: false,
    confirmed_case: null,
    recommended_next_steps: null,
    attributions: [],
    ...overrides,
  };
}

describe("consult reply helpers", () => {
  it("detects insufficient data flag and legacy message", () => {
    expect(isInsufficientReply(mockReply({ insufficient_data: true }))).toBe(true);
    expect(
      isInsufficientReply(
        mockReply({
          response:
            "The data needed to answer this question is not yet available in the system.",
        }),
      ),
    ).toBe(true);
    expect(isInsufficientReply(mockReply({ response: "Cow is grazing normally." }))).toBe(false);
  });

  it("detects vet-confirmed case reuse", () => {
    expect(isConfirmedCaseReply(mockReply({ confirmed_case_reused: true }))).toBe(true);
    expect(
      isConfirmedCaseReply(mockReply({ response: "Similar confirmed case found:\n\n..." })),
    ).toBe(true);
  });

  it("labels provenance source types for UI badges", () => {
    expect(sourceLabel("cow_own_data")).toBe("This cow's data");
    expect(sourceLabel("cross_farm_pattern")).toBe("Cross-farm pattern");
    expect(sourceLabel("research_corpus")).toBe("Research citation");
  });
});
