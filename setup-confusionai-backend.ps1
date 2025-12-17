// frontend/src/App.tsx

import React, { useEffect, useState } from "react";
import { AnalysisResult, CompatibilityMode } from "./types";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

const FREE_DAILY_LIMIT = 5;
const USAGE_KEY = "confusionai_usage_v1";
const PRO_KEY = "confusionai_isPro_v1";

interface UsageState {
  date: string; // YYYY-MM-DD
  count: number;
}

function todayString(): string {
  return new Date().toISOString().slice(0, 10);
}

function loadUsage(): UsageState {
  try {
    const raw = localStorage.getItem(USAGE_KEY);
    if (!raw) {
      return { date: todayString(), count: 0 };
    }
    const parsed = JSON.parse(raw) as UsageState;
    if (parsed.date !== todayString()) {
      return { date: todayString(), count: 0 };
    }
    return parsed;
  } catch {
    return { date: todayString(), count: 0 };
  }
}

function saveUsage(usage: UsageState) {
  localStorage.setItem(USAGE_KEY, JSON.stringify(usage));
}

function loadIsPro(): boolean {
  try {
    const raw = localStorage.getItem(PRO_KEY);
    return raw === "true";
  } catch {
    return false;
  }
}

function saveIsPro(value: boolean) {
  localStorage.setItem(PRO_KEY, value ? "true" : "false");
}

function backgroundClassForMode(mode: CompatibilityMode | null): string {
  if (!mode) {
    return "from-slate-900 via-slate-950 to-black";
  }
  switch (mode) {
    case "honest":
      return "from-emerald-500/40 via-emerald-800/20 to-slate-950";
    case "toxic":
      return "from-red-600/50 via-fuchsia-700/30 to-slate-950";
    case "in_love":
      return "from-sky-500/40 via-indigo-600/30 to-slate-950";
    case "mixed":
    default:
      return "from-amber-400/40 via-purple-600/20 to-slate-950";
  }
}

const App: React.FC = () => {
  const [text, setText] = useState("");
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);

  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadingType, setLoadingType] = useState<"text" | "image" | null>(
    null
  );
  const [error, setError] = useState<string | null>(null);

  const [usage, setUsage] = useState<UsageState>(() => loadUsage());
  const [isPro, setIsPro] = useState<boolean>(() => loadIsPro());
  const [justUpgraded, setJustUpgraded] = useState(false);

  // Handle ?plan=pro after Stripe redirect
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const plan = params.get("plan");
    if (plan === "pro") {
      saveIsPro(true);
      setIsPro(true);
      setJustUpgraded(true);
      // Remove query param from URL (no reload)
      window.history.replaceState({}, "", window.location.pathname);
    }
  }, []);

  // Reset usage if day changed
  useEffect(() => {
    const current = loadUsage();
    if (current.date !== usage.date) {
      const reset: UsageState = { date: todayString(), count: 0 };
      setUsage(reset);
      saveUsage(reset);
    }
  }, []);

  async function ensureCanAnalyze(): Promise<boolean> {
    if (isPro) return true;

    const freshUsage = loadUsage();
    if (freshUsage.date !== todayString()) {
      freshUsage.date = todayString();
      freshUsage.count = 0;
    }

    if (freshUsage.count >= FREE_DAILY_LIMIT) {
      setError(
        "Free plan limit reached for today. Upgrade to Pro for unlimited analyses."
      );
      return false;
    }

    const updated: UsageState = {
      date: freshUsage.date,
      count: freshUsage.count + 1
    };
    setUsage(updated);
    saveUsage(updated);
    return true;
  }

  async function handleAnalyzeText() {
    setError(null);
    setResult(null);

    const trimmed = text.trim();
    if (!trimmed) {
      setError("Please paste a conversation first.");
      return;
    }

    const allowed = await ensureCanAnalyze();
    if (!allowed) return;

    setLoading(true);
    setLoadingType("text");
    try {
      const response = await fetch(`${API_BASE_URL}/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ text: trimmed })
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.error || "Failed to analyze text.");
      }

      const data = (await response.json()) as AnalysisResult;
      setResult(data);
    } catch (err: any) {
      console.error(err);
      setError(
        err?.message || "Something went wrong while analyzing the text."
      );
    } finally {
      setLoading(false);
      setLoadingType(null);
    }
  }

  async function handleAnalyzeImage() {
    setError(null);
    setResult(null);

    if (!imageFile) {
      setError("Please choose a screenshot image first.");
      return;
    }

    const allowed = await ensureCanAnalyze();
    if (!allowed) return;

    setLoading(true);
    setLoadingType("image");
    try {
      const formData = new FormData();
      formData.append("image", imageFile);

      const response = await fetch(`${API_BASE_URL}/analyze-image`, {
        method: "POST",
        body: formData
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.error || "Failed to analyze screenshot.");
      }

      const data = (await response.json()) as AnalysisResult;
      setResult(data);
    } catch (err: any) {
      console.error(err);
      setError(
        err?.message || "Something went wrong while analyzing the screenshot."
      );
    } finally {
      setLoading(false);
      setLoadingType(null);
    }
  }

  function handleImageChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setImageFile(file);
    const url = URL.createObjectURL(file);
    setImagePreview(url);
  }

  async function handleUpgradeToPro() {
    setError(null);
    try {
      const response = await fetch(`${API_BASE_URL}/create-checkout-session`, {
        method: "POST"
      });
      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.error || "Failed to start checkout.");
      }
      const data = await response.json();
      if (data.url) {
        window.location.href = data.url;
      } else {
        throw new Error("No checkout URL returned from server.");
      }
    } catch (err: any) {
      console.error(err);
      setError(
        err?.message || "Something went wrong while starting the upgrade flow."
      );
    }
  }

  const gaugeMode: CompatibilityMode | null = result ? result.mode : null;
  const backgroundGradient = backgroundClassForMode(gaugeMode);
  const usageLeft = Math.max(FREE_DAILY_LIMIT - usage.count, 0);

  return (
    <div
      className={`min-h-screen bg-gradient-to-br ${backgroundGradient} text-slate-50 flex flex-col`}
    >
      {/* Top bar */}
      <header className="border-b border-white/10 bg-black/40 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl border border-emerald-400/60 bg-black/60 flex items-center justify-center text-emerald-300 font-bold text-xl shadow-[0_0_20px_rgba(16,185,129,0.6)]">
              CA
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-lg font-semibold tracking-tight">
                  Confusion-AI
                </h1>
                <span className="rounded-full border border-emerald-400/60 bg-emerald-500/10 px-2 py-0.5 text-[10px] uppercase tracking-wide text-emerald-300">
                  Innovative Solutions
                </span>
              </div>
              <p className="text-xs text-slate-300/80">
                Vibe analyzer for conversations & compatibility scanner for
                chats.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="rounded-full border border-slate-500/60 bg-black/40 px-3 py-1 text-xs flex flex-col min-w-[160px]">
              <span className="font-semibold text-[11px]">
                {isPro ? "Pro: Unlimited analyses" : "Free plan"}
              </span>
              {!isPro && (
                <span className="text-[11px] text-slate-300/90">
                  {usage.count}/{FREE_DAILY_LIMIT} used today
                  {usageLeft > 0 ? ` • ${usageLeft} left` : ""}
                </span>
              )}
            </div>
            {!isPro && (
              <button
                onClick={handleUpgradeToPro}
                className="rounded-full bg-emerald-500 px-4 py-1.5 text-xs font-semibold text-black shadow-lg shadow-emerald-500/40 hover:bg-emerald-400 transition"
              >
                Upgrade to Pro
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="flex-1">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-6 lg:flex-row">
          {/* Left: Input & actions */}
          <section className="flex-1 space-y-4">
            <div className="rounded-3xl border border-white/10 bg-black/40 p-4 shadow-xl shadow-black/40">
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-sm font-semibold tracking-wide text-slate-100">
                  Paste your conversation
                </h2>
                <span className="rounded-full bg-slate-800/80 px-2 py-0.5 text-[10px] uppercase tracking-wide text-slate-300">
                  Text analysis
                </span>
              </div>
              <textarea
                className="min-h-[180px] w-full resize-none rounded-2xl border border-slate-700/70 bg-slate-950/80 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                placeholder="Paste any chat, DMs, texts, or messages here. Confusion-AI will scan for honesty, gaslighting, hidden agenda, miscommunication, and more..."
                value={text}
                onChange={(e) => setText(e.target.value)}
              />
              <div className="mt-3 flex items-center justify-between">
                <p className="text-[11px] text-slate-400">
                  Confusion-AI uses OpenAI to analyze emotional dynamics. Never
                  share truly private or sensitive data.
                </p>
                <button
                  onClick={handleAnalyzeText}
                  disabled={loading}
                  className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-4 py-2 text-xs font-semibold text-black shadow-lg shadow-emerald-500/40 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {loading && loadingType === "text" ? (
                    <span className="animate-pulse">Analyzing...</span>
                  ) : (
                    <>
                      <span>Analyze Text</span>
                      <span className="text-[9px]">⚡</span>
                    </>
                  )}
                </button>
              </div>
            </div>

            <div className="rounded-3xl border border-purple-400/30 bg-black/40 p-4 shadow-xl shadow-purple-900/50">
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-sm font-semibold tracking-wide text-slate-100">
                  Or upload a screenshot
                </h2>
                <span className="rounded-full bg-purple-900/60 px-2 py-0.5 text-[10px] uppercase tracking-wide text-purple-200">
                  Vision analysis
                </span>
              </div>

              <div className="flex flex-col gap-3 md:flex-row">
                <label className="flex flex-1 cursor-pointer flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-purple-400/40 bg-slate-950/60 px-3 py-4 text-center text-xs text-slate-300 hover:border-purple-300/80 hover:bg-slate-900/80">
                  <span className="text-base">📸</span>
                  <span className="font-medium">
                    Drop a screenshot or click to browse
                  </span>
                  <span className="text-[11px] text-slate-400">
                    JPG, PNG • up to 5MB
                  </span>
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={handleImageChange}
                  />
                </label>

                {imagePreview && (
                  <div className="w-full max-w-[160px] overflow-hidden rounded-2xl border border-purple-500/60 bg-black/60">
                    <img
                      src={imagePreview}
                      alt="Screenshot preview"
                      className="h-full w-full object-cover"
                    />
                  </div>
                )}
              </div>

              <div className="mt-3 flex items-center justify-between">
                <p className="text-[11px] text-slate-400">
                  We only send the screenshot to OpenAI for analysis and do not
                  store it on the server (demo implementation).
                </p>
                <button
                  onClick={handleAnalyzeImage}
                  disabled={loading}
                  className="inline-flex items-center gap-2 rounded-full bg-purple-500 px-4 py-2 text-xs font-semibold text-black shadow-lg shadow-purple-500/40 hover:bg-purple-400 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {loading && loadingType === "image" ? (
                    <span className="animate-pulse">Analyzing...</span>
                  ) : (
                    <>
                      <span>Analyze Screenshot</span>
                      <span className="text-[9px]">👁️</span>
                    </>
                  )}
                </button>
              </div>
            </div>

            {error && (
              <div className="rounded-2xl border border-red-500/70 bg-red-950/60 px-3 py-2 text-xs text-red-100">
                {error}
              </div>
            )}

            {justUpgraded && (
              <div className="rounded-2xl border border-emerald-500/70 bg-emerald-950/60 px-3 py-2 text-xs text-emerald-100">
                🎉 Welcome to Confusion-AI Pro! You now have unlimited daily
                analyses on this device.
              </div>
            )}
          </section>

          {/* Right: Gauge & metrics */}
          <section className="flex-1 space-y-4">
            <div className="rounded-3xl border border-white/10 bg-black/40 p-4 shadow-2xl shadow-black/60">
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-sm font-semibold tracking-wide text-slate-100">
                  Compatibility Gauge
                </h2>
                <span className="text-[11px] text-slate-300/90">
                  {result
                    ? result.compatibilityLabel
                    : "Run an analysis to see the vibe"}
                </span>
              </div>

              <div className="flex flex-col gap-4 md:flex-row md:items-center">
                <div className="flex flex-1 items-center justify-center">
                  <div className="relative h-40 w-40">
                    <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-emerald-400/30 via-cyan-400/20 to-fuchsia-500/30 blur-xl" />
                    <div className="relative flex h-full w-full items-center justify-center rounded-full border border-slate-600/60 bg-slate-950/80 shadow-[0_0_30px_rgba(59,130,246,0.4)]">
                      <div className="flex h-[80%] w-[80%] flex-col items-center justify-center rounded-full bg-black/80">
                        <span className="text-[11px] uppercase tracking-wide text-slate-400">
                          Overall
                        </span>
                        <span className="text-4xl font-bold">
                          {result ? result.overallCompatibility : "--"}
                        </span>
                        <span className="text-xs text-slate-300">/100</span>
                        <span className="mt-1 rounded-full bg-slate-800/80 px-2 py-0.5 text-[10px] text-slate-200">
                          {result
                            ? result.mode === "honest"
                              ? "Honest"
                              : result.mode === "toxic"
                              ? "Toxic"
                              : result.mode === "in_love"
                              ? "In Love"
                              : "Mixed Signals"
                            : "Awaiting scan"}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex-1 space-y-2">
                  <h3 className="text-xs font-semibold uppercase tracking-wide text-slate-300">
                    Key signals
                  </h3>
                  <GaugeRow
                    label="Honesty"
                    value={result?.honesty}
                    accent="bg-emerald-400"
                  />
                  <GaugeRow
                    label="Gaslighting"
                    value={result?.gaslighting}
                    accent="bg-red-400"
                  />
                  <GaugeRow
                    label="Hidden agenda"
                    value={result?.hiddenAgenda}
                    accent="bg-orange-400"
                  />
                  <GaugeRow
                    label="Miscommunication"
                    value={result?.miscommunication}
                    accent="bg-amber-400"
                  />
                  <GaugeRow
                    label="In love"
                    value={result?.inLove}
                    accent="bg-sky-400"
                  />
                  <GaugeRow
                    label="Flirting"
                    value={result?.flirting}
                    accent="bg-pink-400"
                  />
                  <GaugeRow
                    label="Shy"
                    value={result?.shy}
                    accent="bg-violet-400"
                  />
                </div>
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-black/50 p-4 shadow-xl shadow-black/50">
              <h2 className="mb-2 text-sm font-semibold tracking-wide text-slate-100">
                Confusion-AI Summary
              </h2>
              <div className="rounded-2xl border border-slate-700/70 bg-slate-950/80 p-3 text-sm text-slate-100 min-h-[90px]">
                {result ? (
                  <p>{result.summary}</p>
                ) : (
                  <p className="text-slate-400">
                    Paste a conversation or upload a screenshot, then hit
                    analyze to see Confusion-AI&apos;s take on honesty,
                    toxicity, and compatibility.
                  </p>
                )}
              </div>
              <p className="mt-2 text-[10px] text-slate-500">
                Confusion-AI is for entertainment & insight only and is not a
                substitute for professional advice.
              </p>
            </div>
          </section>
        </div>
      </main>

      {/* Watermark */}
      <footer className="pointer-events-none fixed bottom-3 right-4 text-[11px] font-semibold tracking-widest text-slate-500/70">
        Innovative Solutions
      </footer>
    </div>
  );
};

interface GaugeRowProps {
  label: string;
  value?: number;
  accent: string;
}

const GaugeRow: React.FC<GaugeRowProps> = ({ label, value, accent }) => {
  const safeValue =
    typeof value === "number" && value >= 0 && value <= 100 ? value : null;

  return (
    <div className="space-y-1">
      <div className="flex items-center justify-between text-[11px] text-slate-300">
        <span>{label}</span>
        <span className="tabular-nums">
          {safeValue !== null ? `${safeValue}/100` : "--"}
        </span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-slate-800/80">
        {safeValue !== null && (
          <div
            className={`${accent} h-full rounded-full transition-all duration-300`}
            style={{ width: `${safeValue}%` }}
          />
        )}
      </div>
    </div>
  );
};

export default App;
