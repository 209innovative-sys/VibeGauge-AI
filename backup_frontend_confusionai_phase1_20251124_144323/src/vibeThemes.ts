import type { VibeMode } from "./types";

export type PulseStrength = "soft" | "medium" | "strong";

export interface VibeTheme {
  label: string;
  background: string;
  accent: string;
  text: string;
  pulse: PulseStrength;
}

export const vibeThemes: Record<VibeMode, VibeTheme> = {
  calm: {
    label: "Calm",
    background:
      "radial-gradient(circle at top, #0f172a 0%, #020617 60%, #020617 100%)",
    accent: "#38bdf8",
    text: "#e2e8f0",
    pulse: "soft",
  },
  positive: {
    label: "Positive",
    background:
      "radial-gradient(circle at top, #0f172a 0%, #064e3b 55%, #022c22 100%)",
    accent: "#22c55e",
    text: "#ecfdf5",
    pulse: "soft",
  },
  tense: {
    label: "Tense",
    background:
      "radial-gradient(circle at top, #1e1b4b 0%, #4c1d95 55%, #020617 100%)",
    accent: "#a855f7",
    text: "#f5f3ff",
    pulse: "medium",
  },
  hostile: {
    label: "Hostile",
    background:
      "radial-gradient(circle at top, #020617 0%, #450a0a 50%, #111827 100%)",
    accent: "#ef4444",
    text: "#fee2e2",
    pulse: "strong",
  },
  confused: {
    label: "Confused",
    background:
      "radial-gradient(circle at top, #020617 0%, #1e293b 45%, #0f172a 100%)",
    accent: "#facc15",
    text: "#e5e7eb",
    pulse: "soft",
  },
  in_love: {
    label: "In Love",
    background:
      "radial-gradient(circle at top, #2e1065 0%, #9f1239 50%, #020617 100%)",
    accent: "#fb7185",
    text: "#ffe4e6",
    pulse: "medium",
  },
  flirty: {
    label: "Flirty",
    background:
      "radial-gradient(circle at top, #4c1d95 0%, #db2777 50%, #020617 100%)",
    accent: "#f472b6",
    text: "#fdf2f8",
    pulse: "medium",
  },
  shy: {
    label: "Shy",
    background:
      "radial-gradient(circle at top, #020617 0%, #111827 40%, #312e81 100%)",
    accent: "#a855f7",
    text: "#e0e7ff",
    pulse: "soft",
  },
};

export const getVibeTheme = (vibe: VibeMode): VibeTheme =>
  vibeThemes[vibe] ?? vibeThemes.calm;