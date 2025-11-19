import React, { useState } from "react";
import { motion } from "framer-motion";
import {
  Share2,
  Sparkles,
  MessageCircle,
  Gauge,
  ShieldQuestion,
  HeartHandshake,
  User2,
} from "lucide-react";
import clsx from "clsx";
import type { AnalysisResult, ChatMessage } from "../types";
import { getVibeTheme } from "../vibeThemes";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

const initialAnalysis: AnalysisResult = {
  vibe: "calm",
  score: 68,
  sentiment: 0.74,
  tension: 0.21,
  honesty: 0.88,
  gaslighting: 0.05,
  hiddenAgenda: 0.12,
  miscommunication: 0.19,
  inLove: 0.12,
  flirting: 0.08,
  shy: 0.18,
  summary:
    "Conversation tone appears mostly calm and cooperative with light emotional undercurrents. There is room for clearer expression, but no major red flags stand out in this sample.",
  isProUser: true,
  psychEval:
    "Overall emotional climate feels stable with modest tension spikes. There are hints of guardedness and soft vulnerability, but both parties seem open to constructive dialogue when prompted.",
  anonymousMode: true,
};

const initialMessages: ChatMessage[] = [
  {
    id: 1,
    author: "you",
    text: "Hey, I just want to make sure we are on the same page about everything.",
  },
  {
    id: 2,
    author: "them",
    text: "Yeah, I appreciate you checking in. I'm not upset, just trying to process things.",
  },
];

const percentage = (value: number) => Math.round(value * 100);

export const VibeDashboard: React.FC = () => {
  const [analysis, setAnalysis] = useState<AnalysisResult>(initialAnalysis);
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [input, setInput] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isAnonymous, setIsAnonymous] = useState<boolean>(
    initialAnalysis.anonymousMode
  );

  const theme = getVibeTheme(analysis.vibe);
  const vibeLabel = theme.label;
  const vibeScore = analysis.score;

  const handleShare = async () => {
    const shareData = {
      title: "VibeGauge-AI",
      text: "Check out this conversation vibe analyzer.",
      url: window.location.href,
    };

    try {
      const nav: any = navigator;
      if (nav.share) {
        await nav.share(shareData);
      } else if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(window.location.href);
        alert("Link copied to clipboard.");
      } else {
        alert("Share this link: " + window.location.href);
      }
    } catch (err) {
      console.error("Error while sharing", err);
    }
  };

  const handleSubscribe = () => {
    console.log("Subscribe clicked – hook up Stripe here.");
    alert("Subscribe flow coming soon...");
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!input.trim() || isSubmitting) return;

    setIsSubmitting(true);

    const newMessage: ChatMessage = {
      id: Date.now(),
      author: "you",
      text: input.trim(),
    };

    const updatedMessages = [...messages, newMessage];
    const echoMessage: ChatMessage = {
      id: Date.now() + 1,
      author: "them",
      text: "Got it. Let me process that for a second...",
    };

    const messagesForAnalysis = [...updatedMessages, echoMessage];

    setMessages(messagesForAnalysis);
    setInput("");

    try {
      const response = await fetch(`${API_BASE_URL}/analyze`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: messagesForAnalysis,
          metadata: { source: "vibegauge-ui" },
          anonymousMode: isAnonymous,
        }),
      });

      if (!response.ok) {
        console.error("Analyze failed", await response.text());
        alert("Analyze failed – check backend logs.");
      } else {
        const data: AnalysisResult = await response.json();
        setAnalysis(data);
        setIsAnonymous(data.anonymousMode);
      }
    } catch (err) {
      console.error("Error calling /analyze", err);
      alert("Could not reach the analysis server.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const sessionLabel = analysis.anonymousMode
    ? "Anonymous testers"
    : "Linked to profile";

  return (
    <div
      className={clsx(
        "min-h-screen w-full text-sm sm:text-base",
        "flex flex-col items-center",
        `pulse-${theme.pulse}`
      )}
      style={{
        backgroundImage: theme.background,
        color: theme.text,
      }}
    >
      <div className="w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        {/* Top Navigation */}
        <header className="glass-panel mb-6 sm:mb-8 px-4 sm:px-6 py-3 sm:py-4 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div
              className="flex h-9 w-9 items-center justify-center rounded-2xl border border-sky-400/70
                         bg-slate-900/80 shadow-lg shadow-sky-500/40"
            >
              <span className="text-xs font-semibold tracking-[0.18em] text-sky-300">
                VG
              </span>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base sm:text-lg font-semibold tracking-tight">
                  VibeGauge
                </h1>
                <span className="inline-flex items-center gap-1 rounded-full border border-emerald-400/40 bg-emerald-500/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-[0.18em] text-emerald-300">
                  <Sparkles className="h-3 w-3" />
                  Live
                </span>
              </div>
              <p className="mt-0.5 text-[11px] sm:text-xs text-slate-300/80">
                Real-time conversation vibe radar · mock model wired to backend
              </p>
            </div>
          </div>

          <nav className="hidden md:flex items-center gap-4 text-xs text-slate-300">
            <button className="rounded-full px-3 py-1.5 bg-slate-900/80 border border-slate-500/60 text-slate-50 shadow-sm shadow-sky-500/40">
              Dashboard
            </button>
            <button className="px-2.5 py-1.5 rounded-full hover:bg-slate-900/70">
              Analyze
            </button>
            <button className="px-2.5 py-1.5 rounded-full hover:bg-slate-900/70">
              Chat
            </button>
            <button className="px-2.5 py-1.5 rounded-full hover:bg-slate-900/70">
              Profile
            </button>
          </nav>

          <div className="flex items-center gap-2 sm:gap-3">
            <button
              type="button"
              onClick={handleShare}
              className="inline-flex items-center gap-1.5 rounded-full border border-slate-500/70 bg-slate-950/70 px-2.5 sm:px-3 py-1.5 text-[11px] sm:text-xs font-medium text-slate-100 hover:bg-slate-900/90 transition-colors"
            >
              <Share2 className="h-3.5 w-3.5" />
              <span>Share</span>
            </button>
            <button
              type="button"
              onClick={handleSubscribe}
              className="inline-flex items-center gap-1.5 rounded-full bg-sky-500/90 px-3 sm:px-3.5 py-1.5 text-[11px] sm:text-xs font-semibold text-slate-950 shadow-lg shadow-sky-500/50 hover:bg-sky-400 transition-colors"
            >
              <Sparkles className="h-3.5 w-3.5" />
              <span>Subscribe</span>
            </button>
          </div>
        </header>

        {/* Status line */}
        <section className="mb-4 flex flex-col sm:flex-row gap-2 sm:items-center sm:justify-between text-[11px] sm:text-xs text-slate-200/90">
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1 rounded-full bg-slate-900/80 px-2 py-1 border border-slate-600/70">
              <Gauge className="h-3.5 w-3.5 text-sky-300" />
              <span className="uppercase tracking-[0.18em] text-[10px] text-slate-300">
                Current vibe
              </span>
            </span>
            <span className="font-medium">
              {vibeLabel} · <span className="text-sky-300">{vibeScore}/100</span>
            </span>
          </div>
          <div className="flex items-center gap-2">
            <span
              className={clsx(
                "inline-flex items-center gap-1 rounded-full px-2 py-1 border text-[10px] uppercase tracking-[0.16em]",
                analysis.anonymousMode
                  ? "border-amber-400/60 bg-amber-500/10 text-amber-200"
                  : "border-emerald-400/60 bg-emerald-500/10 text-emerald-200"
              )}
            >
              <ShieldQuestion className="h-3.5 w-3.5" />
              {sessionLabel}
            </span>
          </div>
        </section>

        {/* Main layout */}
        <main className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 items-start">
          {/* Left column: Gauge + metrics */}
          <div className="space-y-4 sm:space-y-5">
            {/* Gauge and summary */}
            <motion.div
              className="glass-panel px-4 sm:px-5 py-4 sm:py-5"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.35 }}
            >
              <div className="flex flex-col md:flex-row gap-4 md:gap-5 items-stretch">
                <div className="flex items-center justify-center md:w-1/2">
                  <motion.div
                    className="relative h-40 w-40 sm:h-44 sm:w-44 rounded-full flex items-center justify-center"
                    style={{
                      backgroundImage:
                        "conic-gradient(from 220deg, #22c55e, #22c55e 20%, #0ea5e9 40%, #6366f1 60%, #ec4899 80%, #ef4444 100%)",
                    }}
                    animate={{
                      rotate: [0, 2, -1.5, 0],
                      scale: [1, 1.02, 1.01, 1],
                    }}
                    transition={{
                      duration: 6,
                      repeat: Infinity,
                      repeatType: "mirror",
                    }}
                  >
                    <div className="absolute inset-[10%] rounded-full bg-slate-950/80 blur-xl" />
                    <div className="relative h-28 w-28 sm:h-32 sm:w-32 rounded-full bg-slate-950/90 border border-slate-500/60 flex flex-col items-center justify-center shadow-inner shadow-slate-900/90">
                      <div className="text-[11px] uppercase tracking-[0.2em] text-slate-400">
                        Vibe Index
                      </div>
                      <div className="mt-1 flex items-end gap-1">
                        <span className="text-3xl sm:text-4xl font-semibold">
                          {vibeScore}
                        </span>
                        <span className="mb-1 text-[10px] text-slate-400">
                          /100
                        </span>
                      </div>
                      <div className="mt-1 text-xs font-medium text-sky-200">
                        {vibeLabel}
                      </div>
                    </div>
                  </motion.div>
                </div>

                <div className="md:w-1/2 flex flex-col justify-between gap-3 sm:gap-4">
                  <div>
                    <h2 className="text-sm sm:text-base font-semibold mb-1.5">
                      Session overview
                    </h2>
                    <p className="text-xs sm:text-[13px] text-slate-200/85 leading-relaxed">
                      {analysis.summary}
                    </p>
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-[11px] sm:text-xs">
                    <div className="rounded-xl bg-slate-900/80 border border-slate-600/60 px-2.5 py-2">
                      <div className="text-[10px] uppercase tracking-[0.18em] text-slate-400 mb-1">
                        Sentiment
                      </div>
                      <div className="flex items-baseline gap-1">
                        <span className="text-sm font-semibold">
                          {percentage(analysis.sentiment)}%
                        </span>
                      </div>
                    </div>
                    <div className="rounded-xl bg-slate-900/80 border border-slate-600/60 px-2.5 py-2">
                      <div className="text-[10px] uppercase tracking-[0.18em] text-slate-400 mb-1">
                        Tension
                      </div>
                      <div className="flex items-baseline gap-1">
                        <span className="text-sm font-semibold">
                          {percentage(analysis.tension)}%
                        </span>
                      </div>
                    </div>
                    <div className="rounded-xl bg-slate-900/80 border border-slate-600/60 px-2.5 py-2">
                      <div className="text-[10px] uppercase tracking-[0.18em] text-slate-400 mb-1">
                        Honesty
                      </div>
                      <div className="flex items-baseline gap-1">
                        <span className="text-sm font-semibold">
                          {percentage(analysis.honesty)}%
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-950/70 border border-slate-600/70 px-3 py-2.5">
                    <div className="flex items-center justify-between gap-2 text-[11px]">
                      <div className="flex items-center gap-1.5 text-slate-200">
                        <HeartHandshake className="h-3.5 w-3.5 text-pink-300" />
                        <span className="uppercase tracking-[0.18em] text-[10px] text-slate-300">
                          Romantic signals
                        </span>
                      </div>
                      <span className="text-[10px] text-slate-400">
                        Experimental · not medical advice
                      </span>
                    </div>
                    <div className="mt-2 grid grid-cols-3 gap-2 text-[11px]">
                      <div>
                        <div className="text-[10px] text-slate-400 mb-0.5">
                          In love
                        </div>
                        <div className="font-medium">
                          {percentage(analysis.inLove)}%
                        </div>
                      </div>
                      <div>
                        <div className="text-[10px] text-slate-400 mb-0.5">
                          Flirting
                        </div>
                        <div className="font-medium">
                          {percentage(analysis.flirting)}%
                        </div>
                      </div>
                      <div>
                        <div className="text-[10px] text-slate-400 mb-0.5">
                          Shy
                        </div>
                        <div className="font-medium">
                          {percentage(analysis.shy)}%
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>

            {/* Signal metrics */}
            <motion.div
              className="glass-panel px-4 sm:px-5 py-4 sm:py-5"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.35, delay: 0.05 }}
            >
              <div className="flex items-center justify-between mb-3">
                <div>
                  <h3 className="text-sm sm:text-base font-semibold">
                    Signal radar
                  </h3>
                  <p className="text-[11px] sm:text-xs text-slate-300/85">
                    Honesty, gaslighting, hidden agenda, and miscommunication
                    are displayed as experimental AI indicators.
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {[
                  {
                    key: "honesty",
                    label: "Honesty",
                    value: analysis.honesty,
                    accentFrom: "#22c55e",
                    accentTo: "#4ade80",
                  },
                  {
                    key: "gaslighting",
                    label: "Gaslighting",
                    value: analysis.gaslighting,
                    accentFrom: "#f97316",
                    accentTo: "#fb923c",
                  },
                  {
                    key: "hiddenAgenda",
                    label: "Hidden agenda",
                    value: analysis.hiddenAgenda,
                    accentFrom: "#a855f7",
                    accentTo: "#8b5cf6",
                  },
                  {
                    key: "miscommunication",
                    label: "Miscommunication",
                    value: analysis.miscommunication,
                    accentFrom: "#38bdf8",
                    accentTo: "#22d3ee",
                  },
                ].map((metric) => (
                  <div
                    key={metric.key}
                    className="rounded-2xl bg-slate-950/80 border border-slate-600/70 px-3 py-2.5 flex flex-col gap-1.5"
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium">
                        {metric.label}
                      </span>
                      <span className="text-xs text-slate-300/90">
                        {percentage(metric.value)}%
                      </span>
                    </div>
                    <div className="h-1.5 rounded-full bg-slate-800 overflow-hidden">
                      <div
                        className="h-full rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            Math.max(0, percentage(metric.value))
                          )}%`,
                          backgroundImage: `linear-gradient(90deg, ${metric.accentFrom}, ${metric.accentTo})`,
                        }}
                      />
                    </div>
                    <p className="text-[10px] text-slate-400 mt-0.5">
                      Experimental AI signal – not a diagnosis.
                    </p>
                  </div>
                ))}
              </div>
            </motion.div>

            {/* Psych eval */}
            {analysis.isProUser && analysis.psychEval && (
              <motion.div
                className="glass-panel px-4 sm:px-5 py-4 sm:py-5"
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.35, delay: 0.1 }}
              >
                <div className="flex items-start gap-3">
                  <div className="mt-0.5">
                    <User2 className="h-4 w-4 text-emerald-300" />
                  </div>
                  <div className="flex-1 space-y-1.5">
                    <div className="flex items-center justify-between gap-2">
                      <h3 className="text-sm font-semibold">
                        Deep insight (Pro)
                      </h3>
                      <span className="inline-flex items-center gap-1 rounded-full border border-slate-500/70 bg-slate-900/80 px-2 py-0.5 text-[10px] uppercase tracking-[0.16em] text-slate-300">
                        Optional · Not medical advice
                      </span>
                    </div>
                    <p className="text-xs text-slate-200/90 leading-relaxed">
                      {analysis.psychEval}
                    </p>
                  </div>
                </div>
              </motion.div>
            )}
          </div>

          {/* Right column: Chat */}
          <motion.section
            className="glass-panel px-4 sm:px-5 py-4 sm:py-5 flex flex-col h-[420px] sm:h-[460px] lg:h-full"
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35, delay: 0.05 }}
          >
            <header className="mb-3 flex items-start justify-between gap-3">
              <div>
                <div className="flex items-center gap-2">
                  <MessageCircle className="h-4 w-4 text-sky-300" />
                  <h2 className="text-sm sm:text-base font-semibold">
                    Chat
                  </h2>
                </div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-300/85">
                  Feed in your conversation and watch the vibe react in real
                  time.
                </p>
              </div>
              <div className="flex flex-col items-end gap-1">
                <span className="inline-flex items-center gap-1 rounded-full bg-slate-950/80 border border-slate-600/70 px-2 py-0.5 text-[10px] uppercase tracking-[0.16em] text-slate-300">
                  <Sparkles className="h-3 w-3 text-sky-300" />
                  Demo model
                </span>
                <span className="text-[10px] text-slate-400">
                  {sessionLabel}
                </span>
              </div>
            </header>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto space-y-2 pr-1 scrollbar-thin">
              {messages.map((message) => {
                const fromYou = message.author === "you";
                return (
                  <div
                    key={message.id}
                    className={clsx(
                      "flex w-full",
                      fromYou ? "justify-end" : "justify-start"
                    )}
                  >
                    <div
                      className={clsx(
                        "max-w-[80%] rounded-2xl px-3 py-2 text-xs sm:text-[13px] leading-relaxed",
                        fromYou
                          ? "bg-sky-500/80 text-slate-950 shadow-lg shadow-sky-500/60"
                          : "bg-slate-900/80 border border-slate-600/70 text-slate-50"
                      )}
                    >
                      {message.text}
                    </div>
                  </div>
                );
              })}
              {messages.length === 0 && (
                <div className="text-[11px] text-slate-400">
                  No messages yet. Paste or type a conversation to analyze its
                  vibe.
                </div>
              )}
            </div>

            {/* Composer */}
            <form
              onSubmit={handleSubmit}
              className="mt-3 border-t border-slate-700/70 pt-3 space-y-2"
            >
              <div className="flex items-center justify-between gap-2">
                <label className="inline-flex items-center gap-2 text-[11px] text-slate-300 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={isAnonymous}
                    onChange={(e) => {
                      const next = e.target.checked;
                      setIsAnonymous(next);
                      setAnalysis((prev) => ({
                        ...prev,
                        anonymousMode: next,
                      }));
                    }}
                    className="h-3.5 w-3.5 rounded border-slate-500 bg-slate-900 text-sky-400 focus:ring-sky-500"
                  />
                  <span>Anonymous session</span>
                </label>
                <span className="text-[10px] text-slate-400">
                  Messages stay in this browser · mock API only
                </span>
              </div>

              <div className="flex flex-col sm:flex-row gap-2">
                <textarea
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  rows={2}
                  placeholder="Type or paste the next message in your conversation..."
                  className="flex-1 resize-none rounded-xl bg-slate-950/80 border border-slate-700/80 px-3 py-2 text-xs sm:text-[13px] text-slate-50 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500/80 focus:border-sky-500/80"
                />
                <button
                  type="submit"
                  disabled={isSubmitting || !input.trim()}
                  className={clsx(
                    "inline-flex items-center justify-center rounded-xl px-3 sm:px-4 py-2 text-xs sm:text-[13px] font-semibold transition-colors whitespace-nowrap",
                    isSubmitting || !input.trim()
                      ? "bg-slate-700 text-slate-300 cursor-not-allowed"
                      : "bg-sky-500 text-slate-950 shadow-lg shadow-sky-500/60 hover:bg-sky-400"
                  )}
                >
                  {isSubmitting ? "Analyzing..." : "Send & Analyze"}
                </button>
              </div>
              <p className="text-[10px] text-slate-500">
                Uses backend <code>/analyze</code> endpoint with mocked
                AnalysisResult. Swap in your real model when ready.
              </p>
            </form>
          </motion.section>
        </main>
      </div>
    </div>
  );
};