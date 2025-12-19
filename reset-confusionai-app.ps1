param(
    # Frontend root (change if your frontend lives in a subfolder)
    [string]$FrontendRoot = "."
)

Write-Host "=== Confusion-AI App.tsx reset ===" -ForegroundColor Cyan

$FrontendRoot = (Resolve-Path $FrontendRoot).Path
Write-Host "Frontend root: $FrontendRoot" -ForegroundColor Cyan

# Path to App.tsx (Vite default)
$appPath = Join-Path $FrontendRoot "src\App.tsx"

if (-not (Test-Path $appPath)) {
    Write-Host "ERROR: src\App.tsx not found at $appPath" -ForegroundColor Red
    Write-Host "If your App file is somewhere else, re-run with -FrontendRoot pointing at the correct folder." -ForegroundColor Red
    exit 1
}

# 1) Backup current App.tsx
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$appDir = Split-Path $appPath -Parent
$backupDir = Join-Path $appDir ("backup_App_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
Copy-Item -Path $appPath -Destination (Join-Path $backupDir "App.tsx") -Force
Write-Host "Backup complete." -ForegroundColor Green

# 2) Write a fresh Confusion-AI App.tsx
Write-Host "Writing new Confusion-AI App.tsx..." -ForegroundColor Yellow

$appContent = @'
import React, { useState } from "react";
import ScreenshotUpload from "./components/ScreenshotUpload";
import BrandWatermark from "./components/BrandWatermark";

type Metric = {
  score: number;
  reason: string;
};

type AnalysisResult = {
  honesty: Metric;
  gaslighting: Metric;
  hiddenAgenda: Metric;
  miscommunication: Metric;
  inLove: Metric;
  flirting: Metric;
  shy: Metric;
  summary: string;
};

const App: React.FC = () => {
  const [text, setText] = useState("");
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const apiBase =
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:5000";

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

      const data = await res.json();
      setResult(data as AnalysisResult);
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
    return (
      <div className="rounded-xl border border-slate-700 bg-slate-900/60 p-3">
        <div className="flex items-center justify-between text-sm font-semibold text-slate-100">
          <span>{label}</span>
          <span className="text-emerald-400">
            {metric.score.toFixed(0)}/100
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-300">{metric.reason}</p>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-6">
        <header className="flex flex-col gap-2 sm:flex-row sm:items-baseline sm:justify-between">
          <div>
            <h1 className="bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-500 bg-clip-text text-3xl font-bold tracking-tight text-transparent">
              Confusion-AI
            </h1>
            <p className="text-xs text-slate-400">
              Drop in your chat or a screenshot. I&apos;ll read the vibe:
              honesty, gaslighting, hidden agenda, miscommunication, inLove,
              flirting, and shy.
            </p>
          </div>
          <span className="rounded-full border border-emerald-500/40 bg-emerald-500/10 px-3 py-1 text-[10px] font-medium uppercase tracking-wide text-emerald-300">
            Innovative Solutions
          </span>
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

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={handleAnalyzeText}
                disabled={isLoading}
                className="inline-flex items-center justify-center rounded-xl bg-emerald-500 px-4 py-2 text-xs font-semibold text-slate-950 shadow-lg shadow-emerald-900/40 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isLoading ? "Analyzing..." : "Analyze Text"}
              </button>
              {error && (
                <span className="text-xs text-red-400">{error}</span>
              )}
            </div>

            <ScreenshotUpload
              onResult={(data) => {
                setResult(data as AnalysisResult);
                setError(null);
              }}
              onError={(message) => {
                setError(message);
              }}
            />
          </section>

          {/* RIGHT: results */}
          <section className="flex flex-col gap-3">
            <h2 className="text-sm font-semibold text-slate-100">
              Vibe breakdown
            </h2>
            {!result && (
              <p className="text-xs text-slate-400">
                Run an analysis to see the vibe breakdown here.
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
                  {renderMetric("Miscommunication", result.miscommunication)}
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
  );
};

export default App;
'@

Set-Content -Path $appPath -Value $appContent -Encoding UTF8

Write-Host "New App.tsx written and default export defined." -ForegroundColor Green
Write-Host "Backup of previous App.tsx is in: $backupDir" -ForegroundColor Cyan
Write-Host "Now run: npm run dev (frontend) and refresh your browser." -ForegroundColor Cyan
