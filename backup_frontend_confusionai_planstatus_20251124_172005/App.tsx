import React, { useEffect, useState } from "react";
import ScreenshotUpload from "./components/ScreenshotUpload";
import BrandWatermark from "./components/BrandWatermark";
import VibeGauge, { CompatibilityMode } from "./components/VibeGauge";
import ConversationPreview from "./components/ConversationPreview";

type Metric = {
  score: number | string;
  reason: string;
};

type AnalysisResult = {
  honesty?: Metric;
  gaslighting?: Metric;
  hiddenAgenda?: Metric;
  miscommunication?: Metric;
  inLove?: Metric;
  flirting?: Metric;
  shy?: Metric;
  summary: string;
};

const FREE_DAILY_LIMIT = 5;
const USAGE_KEY = "confusionai_usage_v1";
const PRO_KEY = "confusionai_isPro_v1";

const toScore = (metric?: Metric): number | null => {
  if (!metric) return null;
  const n = Number(metric.score);
  if (!Number.isFinite(n)) return null;
  return Math.max(0, Math.min(100, n));
};

const average = (values: (number | null | undefined)[]): number | null => {
  const nums = values.filter(
    (v): v is number => typeof v === "number" && Number.isFinite(v)
  );
  if (nums.length === 0) return null;
  const sum = nums.reduce((acc, v) => acc + v, 0);
  return sum / nums.length;
};

const deriveCompatibility = (
  result: AnalysisResult | null
): { mode: CompatibilityMode; overall: number | null } => {
  if (!result) {
    return { mode: "mixed", overall: null };
  }

  const honesty = toScore(result.honesty);
  const gaslighting = toScore(result.gaslighting);
  const hidden = toScore(result.hiddenAgenda);
  const miscommunication = toScore(result.miscommunication);
  const inLove = toScore(result.inLove);
  const flirting = toScore(result.flirting);

  const negativity = average([gaslighting, hidden, miscommunication]); // how toxic
  const romance = average([inLove, flirting]); // how in love
  const honestyScore = honesty;

  let mode: CompatibilityMode = "mixed";

  if (romance !== null && romance >= 60 && (negativity ?? 0) <= 65) {
    mode = "in_love";
  } else if (negativity !== null && negativity >= 60 && (honestyScore ?? 50) <= 50) {
    mode = "toxic";
  } else if (honestyScore !== null && honestyScore >= 60 && (negativity ?? 0) <= 45) {
    mode = "honest";
  }

  let overall: number | null = null;

  if (mode === "toxic" && negativity !== null) {
    overall = 100 - negativity; // higher toxicity -> lower compatibility
  } else if (mode === "in_love" && romance !== null) {
    overall = romance;
  } else if (mode === "honest" && honestyScore !== null) {
    overall = honestyScore;
  } else {
    overall = average([
      honesty,
      romance,
      negativity !== null ? 100 - negativity : null,
    ]);
  }

  if (overall === null || !Number.isFinite(overall)) {
    return { mode, overall: null };
  }

  return {
    mode,
    overall: Math.max(0, Math.min(100, overall)),
  };
};

const compatibilityTheme: Record<
  CompatibilityMode,
  { base: string; glow: string; accentPill: string }
> = {
  mixed: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(148,163,184,0.35),_rgba(15,23,42,0.98))]",
    accentPill: "text-slate-200 border-slate-400",
  },
  honest: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(34,197,94,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-emerald-300 border-emerald-500/60",
  },
  toxic: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(248,113,113,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-red-300 border-red-500/60",
  },
  in_love: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(59,130,246,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-sky-300 border-sky-500/60",
  },
};

const App: React.FC = () => {
  const [text, setText] = useState("");
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const [isPro, setIsPro] = useState(false);
  const [dailyCount, setDailyCount] = useState(0);

  const [isCreatingCheckout, setIsCreatingCheckout] = useState(false);

  const apiBase =
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  const { mode, overall } = deriveCompatibility(result);
  const theme = compatibilityTheme[mode];

  // Initialize usage & Pro flag from localStorage + URL
  useEffect(() => {
    const today = new Date().toISOString().slice(0, 10);

    try {
      const storedUsage = localStorage.getItem(USAGE_KEY);
      if (storedUsage) {
        const parsed = JSON.parse(storedUsage) as { date?: string; count?: number };
        if (parsed.date === today && typeof parsed.count === "number") {
          setDailyCount(parsed.count);
        } else {
          const fresh = { date: today, count: 0 };
          localStorage.setItem(USAGE_KEY, JSON.stringify(fresh));
          setDailyCount(0);
        }
      } else {
        const fresh = { date: today, count: 0 };
        localStorage.setItem(USAGE_KEY, JSON.stringify(fresh));
        setDailyCount(0);
      }
    } catch (e) {
      console.error("Failed to initialize usage from localStorage", e);
    }

    try {
      const storedPro = localStorage.getItem(PRO_KEY);
      if (storedPro === "true") {
        setIsPro(true);
      }

      const params = new URLSearchParams(window.location.search);
      if (params.get("plan") === "pro") {
        setIsPro(true);
        localStorage.setItem(PRO_KEY, "true");
        params.delete("plan");
        const newQuery = params.toString();
        const newUrl =
          window.location.pathname +
          (newQuery ? "?" + newQuery : "") +
          window.location.hash;
        window.history.replaceState(null, "", newUrl);
      }
    } catch (e) {
      console.error("Failed to initialize Pro flag", e);
    }
  }, []);

  const recordAnalysis = () => {
    const today = new Date().toISOString().slice(0, 10);
    setDailyCount((prev) => {
      const next = prev + 1;
      try {
        localStorage.setItem(
          USAGE_KEY,
          JSON.stringify({ date: today, count: next })
        );
      } catch (e) {
        console.error("Failed to persist usage", e);
      }
      return next;
    });
  };

  const canRunAnotherAnalysis = () => {
    if (isPro) return true;
    if (dailyCount >= FREE_DAILY_LIMIT) {
      setError(
        `Free plan: ${FREE_DAILY_LIMIT} analyses per day. Upgrade to Pro for unlimited compatibility checks.`
      );
      return false;
    }
    return true;
  };

  const handleAnalyzeText = async () => {
    if (!text.trim()) {
      setError("Paste a conversation first.");
      return;
    }

    if (!canRunAnotherAnalysis()) {
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const res = await fetch(`${apiBase}/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ text }),
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Text analysis failed with ${res.status}`);
      }

      const data = (await res.json()) as AnalysisResult;
      setResult(data);
      recordAnalysis();
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Unexpected analysis error.";
      setError(message);
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpgradeClick = async () => {
    try {
      setError(null);
      setIsCreatingCheckout(true);

      const res = await fetch(`${apiBase}/create-checkout-session`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Upgrade failed (${res.status})`);
      }

      const data = (await res.json()) as { url?: string };
      if (data.url) {
        window.location.href = data.url;
        return;
      }
      throw new Error("No checkout URL returned.");
    } catch (err: unknown) {
      const message =
        err instanceof Error
          ? err.message
          : "Upgrade failed. Please try again later.";
      setError(message);
      console.error(err);
    } finally {
      setIsCreatingCheckout(false);
    }
  };

  const renderMetric = (label: string, metric?: Metric) => {
    if (!metric) return null;

    const n = toScore(metric);
    if (n === null) return null;

    return (
      <div className="rounded-xl border border-slate-700 bg-slate-900/60 p-3">
        <div className="flex items-center justify-between text-sm font-semibold text-slate-100">
          <span>{label}</span>
          <span className="text-emerald-400">
            {n.toFixed(0)}/100
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-300">{metric.reason}</p>
      </div>
    );
  };

  const compatibilityPillLabel =
    mode === "honest"
      ? "Compatibility: Honest"
      : mode === "toxic"
      ? "Compatibility: Toxic"
      : mode === "in_love"
      ? "Compatibility: In Love"
      : "Compatibility: Mixed";

  const planPillLabel = isPro
    ? "Pro: unlimited analyses"
    : `Free: ${dailyCount}/${FREE_DAILY_LIMIT} today`;

  const planPillClass = isPro
    ? "border-cyan-400 text-cyan-300"
    : "border-emerald-400 text-emerald-300";

  return (
    <div
      className={`relative min-h-screen text-slate-50 transition-colors duration-700 ${theme.base}`}
    >
      <div
        className={`pointer-events-none absolute inset-0 -z-10 opacity-70 blur-3xl ${theme.glow}`}
      />
      <div className="relative z-10">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-6">
          <header className="flex flex-col gap-3 sm:flex-row sm:items-baseline sm:justify-between">
            <div>
              <h1 className="bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-500 bg-clip-text text-3xl font-bold tracking-tight text-transparent">
                Confusion-AI
              </h1>
              <p className="text-xs text-slate-400">
                Drop in your chat or a screenshot. I&apos;ll read the compatibility:
                honesty, gaslighting, hidden agenda, miscommunication, in love,
                flirting, and shy.
              </p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full border border-emerald-500/40 bg-emerald-500/10 px-3 py-1 text-[10px] font-medium uppercase tracking-wide text-emerald-300">
                Innovative Solutions
              </span>
              <span
                className={`rounded-full border bg-slate-900/70 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${theme.accentPill}`}
              >
                {compatibilityPillLabel}
              </span>
              <span
                className={`rounded-full border bg-slate-900/80 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${pla
 {compatibilityPillLabel}
              </span>
              <span
                className={`rounded-full border bg-slate-900/80 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${planPillClass}`}
              >
                {planPillLabel}
              </span>
              <button
                type="button"
                onClick={handleUpgradeClick}
                disabled={isPro || isCreatingCheckout}
                className="inline-flex items-center justify-center rounded-full bg-fuchsia-500 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-950 shadow-md shadow-fuchsia-900/40 transition hover:bg-fuchsia-400 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isPro
                  ? "Pro active"
                  : isCreatingCheckout
                  ? "Redirecting..."
                  : "Upgrade to Pro"}
              </button>
            </div>
          </header>

          <main className="grid gap-4 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            {/* LEFT: input + chat preview + screenshot */}
            <section className="flex flex-col gap-3">
              <label className="text-xs font-semibold text-slate-200">
                Paste conversation
              </label>
              <textarea
                className="min-h-[160px] w-full rounded-2xl border border-slate-700 bg-slate-950/70 p-3 text-sm text-slate-100 outline-none ring-emerald-500/40 placeholder:text-slate-500 focus:ring-2"
                placeholder="Paste text messages, DMs, or chat logs here..."
                value={text}
                onChange={(e) => setText(e.target.value)}
              />

              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={handleAnalyzeText}
                  disabled={isLoading}
                  className="inline-flex items-center justify-center rounded-xl bg-emerald-500 px-4 py-2 text-xs font-semibold text-slate-950 shadow-lg shadow-emerald-900/40 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isLoading ? "Analyzing..." : "Analyze Text"}
                </button>
                {error && (
                  <span className="text-xs text-red-400 max-w-xs">
                    {error}
                  </span>
                )}
              </div>

              <ConversationPreview rawText={text} />

              <ScreenshotUpload
                canAnalyze={canRunAnotherAnalysis}
                onResult={(data) => {
                  setResult(data as AnalysisResult);
                  setError(null);
                  recordAnalysis();
                }}
                onError={(message) => {
                  setError(message || null);
                }}
              />
            </section>

            {/* RIGHT: gauge + results */}
            <section className="flex flex-col gap-3">
              <VibeGauge score={overall} mode={mode} />

              <h2 className="text-sm font-semibold text-slate-100">
                Compatibility breakdown
              </h2>
              {!result && (
                <p className="text-xs text-slate-400">
                  Run an analysis to see compatibility and detailed metrics here.
                </p>
              )}

              {result && (
                <>
                  <div className="rounded-2xl border border-slate-700 bg-slate-900/80 p-3">
                    <p className="text-xs text-slate-300">{result.summary}</p>
                  </div>
                  <div className="grid grid-cols-1 gap-2 text-xs">
                    {renderMetric("Honesty", result.honesty)}
                    {renderMetric("Gaslighting", result.gaslighting)}
                    {renderMetric("Hidden agenda", result.hiddenAgenda)}
                    {renderMetric(
                      "Miscommunication",
                      result.miscommunication
                    )}
                    {renderMetric("In love", result.inLove)}
                    {renderMetric("Flirting", result.flirting)}
                    {renderMetric("Shy", result.shy)}
                  </div>
                </>
              )}
            </section>
          </main>
        </div>
        <BrandWatermark />
      </div>
    </div>
  );
};

export default App;
