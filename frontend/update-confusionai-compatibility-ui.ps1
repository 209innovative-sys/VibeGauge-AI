param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== Confusion-AI Compatibility UI Update ===" -ForegroundColor Cyan

# Resolve repo root and go there
try {
  $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
}
catch {
  Write-Error "Repo root not found: $RepoRoot"
  exit 1
}

Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
$srcPath = Join-Path $frontendPath "src"
$componentsDir = Join-Path $srcPath "components"
$appPath = Join-Path $srcPath "App.tsx"
$vibeGaugePath = Join-Path $componentsDir "VibeGauge.tsx"

if (-not (Test-Path $frontendPath)) {
  Write-Error "Frontend directory not found at: $frontendPath"
  exit 1
}

if (-not (Test-Path $srcPath)) {
  New-Item -ItemType Directory -Path $srcPath -ErrorAction SilentlyContinue | Out-Null
}

if (-not (Test-Path $componentsDir)) {
  New-Item -ItemType Directory -Path $componentsDir -ErrorAction SilentlyContinue | Out-Null
}

# Backup current files
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_frontend_confusionai_compatibility_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null

if (Test-Path $appPath) {
  Copy-Item -Path $appPath -Destination (Join-Path $backupDir "App.tsx") -Force
  Write-Host "Backed up App.tsx to: $backupDir" -ForegroundColor Green
}

if (Test-Path $vibeGaugePath) {
  Copy-Item -Path $vibeGaugePath -Destination (Join-Path $backupDir "VibeGauge.tsx") -Force
  Write-Host "Backed up VibeGauge.tsx to: $backupDir" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# Write updated VibeGauge.tsx (Compatibility gauge)
# ---------------------------------------------------------------------
Write-Host "Writing updated VibeGauge.tsx to: $vibeGaugePath" -ForegroundColor Yellow

$vibeGaugeContent = @'
import React from "react";

export type CompatibilityMode = "mixed" | "honest" | "toxic" | "in_love";

type VibeGaugeProps = {
  score: number | null;
  mode: CompatibilityMode;
};

const VibeGauge: React.FC<VibeGaugeProps> = ({ score, mode }) => {
  const isPending = score == null || !Number.isFinite(score);
  const clamped = (() => {
    if (isPending) return 0;
    const n = Math.max(0, Math.min(100, score as number));
    return n;
  })();

  const radius = 60;
  const circumference = 2 * Math.PI * radius;
  const progress = (clamped / 100) * circumference;
  const offset = circumference - progress;

  const modeLabelMap: Record<CompatibilityMode, string> = {
    mixed: "Mixed",
    honest: "Honest / Grounded",
    toxic: "Toxic / Chaotic",
    in_love: "In Love / Warm",
  };

  const moodTextMap: Record<CompatibilityMode, string> = {
    mixed:
      "Compatibility is mixed. Some signals support connection, others are pulling against it.",
    honest:
      "Honesty and low manipulation signals suggest a healthy base for compatibility.",
    toxic:
      "High levels of tension, gaslighting, or hidden agenda are dragging compatibility down.",
    in_love:
      "Romantic and flirty signals are strong. Emotional connection looks high here.",
  };

  const accentClassMap: Record<CompatibilityMode, string> = {
    mixed: "text-slate-200",
    honest: "text-emerald-300",
    toxic: "text-red-300",
    in_love: "text-sky-300",
  };

  const activeMode: CompatibilityMode = isPending ? "mixed" : mode;
  const label = isPending ? "Waiting for analysis" : modeLabelMap[activeMode];
  const moodText = isPending
    ? "Run a text or screenshot analysis to see compatibility light up."
    : moodTextMap[activeMode];
  const accent = accentClassMap[activeMode];

  return (
    <div className="flex items-center gap-4 rounded-2xl border border-slate-800 bg-slate-950/70 p-4 shadow-lg shadow-slate-950/60">
      <div className="relative h-32 w-32">
        <svg viewBox="0 0 160 160" className="h-full w-full">
          <defs>
            <linearGradient
              id="compatibilityGaugeGradient"
              x1="0%"
              y1="0%"
              x2="100%"
              y2="0%"
            >
              <stop offset="0%" stopColor="#22c55e" />
              <stop offset="50%" stopColor="#0ea5e9" />
              <stop offset="100%" stopColor="#f97373" />
            </linearGradient>
          </defs>
          <circle
            cx="80"
            cy="80"
            r={radius}
            stroke="#1f2937"
            strokeWidth="14"
            fill="none"
          />
          <circle
            cx="80"
            cy="80"
            r={radius}
            stroke="url(#compatibilityGaugeGradient)"
            strokeWidth="14"
            fill="none"
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            className="transition-all duration-700 ease-out"
            style={{ transformOrigin: "80px 80px", transform: "rotate(-90deg)" }}
          />
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-[10px] font-semibold uppercase tracking-[0.25em] text-slate-500">
            Compatibility
          </span>
          <span className={`text-3xl font-bold ${accent}`}>
            {clamped.toFixed(0)}
          </span>
          <span className="mt-1 text-[11px] text-slate-400">{label}</span>
        </div>
      </div>
      <div className="flex flex-1 flex-col gap-2 text-xs">
        <p className="text-slate-300">{moodText}</p>
        <p className="text-[10px] text-slate-500">
          Derived from honesty, gaslighting, hidden agenda, miscommunication,
          in love, and flirting signals in this conversation.
        </p>
      </div>
    </div>
  );
};

export default VibeGauge;
'@

Set-Content -Path $vibeGaugePath -Value $vibeGaugeContent -Encoding UTF8
Write-Host "Updated VibeGauge.tsx written." -ForegroundColor Green

# ---------------------------------------------------------------------
# Write updated App.tsx (compatibility modes + non-pulsing background)
# ---------------------------------------------------------------------
Write-Host "Writing updated App.tsx to: $appPath" -ForegroundColor Yellow

$appContent = @'
import React, { useState } from "react";
import ScreenshotUpload from "./components/ScreenshotUpload";
import BrandWatermark from "./components/BrandWatermark";
import VibeGauge, { CompatibilityMode } from "./components/VibeGauge";

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

  const apiBase =
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  const { mode, overall } = deriveCompatibility(result);
  const theme = compatibilityTheme[mode];

  const handleAnalyzeText = async () => {
    if (!text.trim()) {
      setError("Paste a conversation first.");
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
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Unexpected analysis error.";
      setError(message);
      console.error(err);
    } finally {
      setIsLoading(false);
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
            </div>
          </header>

          <main className="grid gap-4 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            {/* LEFT: input + screenshot */}
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

              <ScreenshotUpload
                onResult={(data) => {
                  setResult(data as AnalysisResult);
                  setError(null);
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
'@

Set-Content -Path $appPath -Value $appContent -Encoding UTF8
Write-Host "Updated App.tsx written to: $appPath" -ForegroundColor Green

Write-Host "=== Compatibility UI update complete. Restart Vite if needed. ===" -ForegroundColor Cyan
