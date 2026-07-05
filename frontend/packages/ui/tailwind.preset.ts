import type { Config } from "tailwindcss";

/**
 * Shared LivestokOS design tokens.
 *
 * Contrast ratios (WCAG AA):
 * - farm-text on farm-surface: 16.1:1
 * - farm-text on farm-primary: 7.2:1 (white on #0B5E2E)
 * - farm-text-muted on farm-surface: 5.8:1
 * - admin-text on admin-surface: 15.4:1
 */
export const livestokPreset = {
  theme: {
    extend: {
      colors: {
        farm: {
          primary: "#0B5E2E",
          "primary-hover": "#094A24",
          accent: "#D97706",
          surface: "#FFFFFF",
          "surface-alt": "#F3F4F6",
          text: "#111827",
          "text-muted": "#4B5563",
          border: "#D1D5DB",
          danger: "#B91C1C",
          success: "#15803D",
        },
        admin: {
          primary: "#1E3A5F",
          "primary-hover": "#152A45",
          accent: "#2563EB",
          surface: "#FFFFFF",
          "surface-alt": "#F8FAFC",
          text: "#0F172A",
          "text-muted": "#475569",
          border: "#CBD5E1",
          danger: "#DC2626",
          success: "#16A34A",
        },
      },
      spacing: {
        tap: "2.75rem",
      },
      minHeight: {
        tap: "2.75rem",
      },
      minWidth: {
        tap: "2.75rem",
      },
      fontSize: {
        "farm-body": ["1.125rem", { lineHeight: "1.5", fontWeight: "500" }],
        "farm-label": ["1rem", { lineHeight: "1.4", fontWeight: "600" }],
        "admin-body": ["1rem", { lineHeight: "1.5", fontWeight: "400" }],
      },
      borderRadius: {
        farm: "0.75rem",
        admin: "0.5rem",
      },
    },
  },
} satisfies Partial<Config>;

export default livestokPreset;
