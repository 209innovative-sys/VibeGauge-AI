export type VibeMode =
  | "calm"
  | "positive"
  | "tense"
  | "hostile"
  | "confused"
  | "in_love"
  | "flirty"
  | "shy";

export interface AnalysisResult {
  vibe: VibeMode;
  score: number;
  sentiment: number;
  tension: number;
  honesty: number;
  gaslighting: number;
  hiddenAgenda: number;
  miscommunication: number;
  inLove: number;
  flirting: number;
  shy: number;
  summary: string;
  isProUser: boolean;
  psychEval?: string;
  anonymousMode: boolean;
}

export interface ChatMessage {
  id: number;
  author: "you" | "them";
  text: string;
}