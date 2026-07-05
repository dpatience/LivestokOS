import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CaseMemoryPage } from "../pages/CaseMemoryPage";
import { ResearchIngestionPage } from "../pages/ResearchIngestionPage";

const sampleCase = {
  id: 1,
  farm_id: 10,
  farm_name: "Demo Farm",
  cow_id: 20,
  cow_name: "Bessie",
  cow_tag_id: "COW-1",
  situation_summary: "Reduced appetite",
  assistant_answer: "Check ketosis",
  confirmed_at: "2026-07-01T10:00:00Z",
  confirmed_by_user_id: 1,
  inserted_at: "2026-06-30T10:00:00Z",
};

const sampleArticle = {
  id: 1,
  title: "Bovine ketosis review",
  authors: "Smith et al.",
  source: "PubMed",
  url: "https://example.org/paper",
  published_date: "2024-01-15",
  abstract_summary: "Summary text",
  inserted_at: "2026-07-01T12:00:00Z",
};

vi.mock("../context/AdminAuthContext", () => ({
  useAdminAuth: () => ({
    admin: {
      listConfirmedCases: vi.fn().mockResolvedValue({ data: [sampleCase] }),
      revokeConfirmedCase: vi.fn(),
      listResearchArticles: vi.fn().mockResolvedValue({ data: [sampleArticle] }),
      getIngestionStatus: vi.fn().mockResolvedValue({
        data: {
          job: {
            state: "never_run",
            inserted_at: null,
            completed_at: null,
            attempted_at: null,
            errors: [],
          },
          article_count: 1,
        },
      }),
      triggerIngestion: vi.fn(),
    },
  }),
}));

afterEach(() => cleanup());

describe("AI oversight pages", () => {
  it("CaseMemoryPage renders responsive table shell", async () => {
    const { container } = render(<CaseMemoryPage />);
    await waitFor(() => expect(screen.getAllByText("Demo Farm").length).toBeGreaterThanOrEqual(1));
    expect(screen.getByRole("heading", { name: /case memory qc/i })).toBeInTheDocument();
    expect(container.querySelector("table")).toBeTruthy();
    expect(container.querySelector("ul.md\\:hidden")).toBeTruthy();
  });

  it("ResearchIngestionPage renders status and source list shell", async () => {
    const { container } = render(<ResearchIngestionPage />);
    await waitFor(() =>
      expect(screen.getAllByText("Bovine ketosis review").length).toBeGreaterThanOrEqual(1),
    );
    expect(screen.getByRole("heading", { name: /research corpus ingestion/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /trigger ingestion run/i })).toBeInTheDocument();
    expect(container.querySelector("table")).toBeTruthy();
    expect(container.querySelector("ul.md\\:hidden")).toBeTruthy();
  });
});

describe.sequential("ResponsiveDataList at reference breakpoints", () => {
  const breakpoints = [360, 768, 1024, 1280] as const;

  it.each(breakpoints)("CaseMemoryPage keeps table + mobile list DOM at %ipx", async (width) => {
    Object.defineProperty(window, "innerWidth", { writable: true, configurable: true, value: width });
    render(<CaseMemoryPage />);
    await waitFor(() => expect(screen.getAllByText("Demo Farm").length).toBeGreaterThanOrEqual(1));
    expect(screen.getAllByRole("table").length).toBeGreaterThanOrEqual(1);
    expect(document.querySelector("ul.md\\:hidden")).toBeTruthy();
  });

  it.each(breakpoints)(
    "ResearchIngestionPage keeps table + mobile list DOM at %ipx",
    async (width) => {
      Object.defineProperty(window, "innerWidth", { writable: true, configurable: true, value: width });
      render(<ResearchIngestionPage />);
      await waitFor(() =>
        expect(screen.getAllByText("Bovine ketosis review").length).toBeGreaterThanOrEqual(1),
      );
      expect(screen.getAllByRole("table").length).toBeGreaterThanOrEqual(1);
      expect(document.querySelector("ul.md\\:hidden")).toBeTruthy();
    },
  );
});
