param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== Confusion-AI: Focal input + combined screenshot + Googlebar style ===" -ForegroundColor Cyan

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

try { $root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
$frontendPath = Join-Path $root $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend folder not found: $frontendPath"; exit 1 }

$appPath = Join-Path $frontendPath "src\App.tsx"
if (-not (Test-Path $appPath)) { Write-Error "Missing App.tsx: $appPath"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ("backup_focal_input_" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $appPath (Join-Path $backupDir "App.tsx") -Force
Write-Host "Backup: $backupDir\App.tsx" -ForegroundColor DarkGray

# Ensure OnboardingPanel exists (safe overwrite)
$compDir = Join-Path $frontendPath "src\components"
New-Item -ItemType Directory -Force -Path $compDir | Out-Null
$panelPath = Join-Path $compDir "OnboardingPanel.tsx"

$panel = @'
import React, { useMemo, useState } from "react";

type BubbleProps = {
  title: string;
  body: string;
  tone?: "good" | "warn" | "info";
};

function Bubble({ title, body, tone = "info" }: BubbleProps) {
  const toneClasses =
    tone === "good"
      ? "border-emerald-500/30 bg-emerald-500/10"
      : tone === "warn"
      ? "border-fuchsia-500/30 bg-fuchsia-500/10"
      : "border-cyan-500/30 bg-cyan-500/10";

  const tail =
    tone === "good"
      ? "after:border-t-emerald-500/10"
      : tone === "warn"
      ? "after:border-t-fuchsia-500/10"
      : "after:border-t-cyan-500/10";

  return (
    <div
      className={[
        "relative rounded-3xl border p-4",
        toneClasses,
        "after:content-[''] after:absolute after:left-8 after:-bottom-3 after:border-[12px] after:border-x-transparent after:border-b-transparent",
        tail,
      ].join(" ")}
    >
      <div className="text-[11px] font-semibold uppercase tracking-wide text-slate-100/90">
        {title}
      </div>
      <div className="mt-1 text-xs text-slate-200/80 leading-relaxed">
        {body}
      </div>
    </div>
  );
}

type Props = { onFillExample: () => void };

export default function OnboardingPanel({ onFillExample }: Props) {
  const [open, setOpen] = useState(true);

  const steps = useMemo(
    () => [
      { t: "Paste or upload", b: "Paste a chat OR upload a screenshot.", tone: "info" as const },
      { t: "Tap Analyze", b: "You get compatibility + reasons + red flags.", tone: "good" as const },
      { t: "Read the signals", b: "Honesty, gaslighting, hidden agenda, miscommunication, inLove, flirting, shy.", tone: "warn" as const },
    ],
    []
  );

  return (
    <section className="rounded-3xl border border-slate-700/70 bg-slate-900/40 p-4 sm:p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold text-slate-100">Quick start</h2>
          <p className="mt-1 text-xs text-slate-300">Make it obvious for new users.</p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onFillExample}
            className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-[11px] font-semibold text-emerald-200 hover:bg-emerald-500/15"
          >
            Try sample chat
          </button>

          <button
            type="button"
            onClick={() => setOpen(v => !v)}
            className="rounded-xl border border-slate-700 bg-slate-950/40 px-3 py-2 text-[11px] font-semibold text-slate-200 hover:bg-slate-950/60"
          >
            {open ? "Hide" : "Show"}
          </button>
        </div>
      </div>

      {open && (
        <div className="mt-4 grid gap-3 md:grid-cols-3">
          {steps.map((s) => (
            <Bubble key={s.t} title={s.t} body={s.b} tone={s.tone} />
          ))}
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
        <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1">
          Tip: label speakers like “Me:” and “Them:” for cleaner results.
        </span>
        <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1">
          MVP privacy: we don’t store your chats on the server.
        </span>
      </div>
    </section>
  );
}
'@
Write-Utf8NoBom $panelPath $panel

# Overwrite App.tsx clean
$app = @'
import React, { useEffect, useMemo, useState } from "react";
import ScreenshotUpload from "./components/ScreenshotUpload";
import BrandWatermark from "./components/BrandWatermark";
import OnboardingPanel from "./components/OnboardingPanel";

type Metric = { score?: number; reason?: string };
type AnalysisResult = {
  honesty?: Metric;
  gaslighting?: Metric;
  hiddenAgenda?: Metric;
  miscommunication?: Metric;
  inLove?: Metric;
  flirting?: Metric;
  shy?: Metric;
  summary?: string;
};

type PlanStatus = { plan: "free" | "pro"; usedToday: number; freeDailyLimit: number };

const TOKEN_KEY = "confusionai_pro_token";
const CLIENT_KEY = "confusionai_client_id";

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}
function num(x: any, fallback = 0) {
  const n = Number(x);
  return Number.isFinite(n) ? n : fallback;
}
function getClientId(): string {
  try {
    let v = localStorage.getItem(CLIENT_KEY);
    if (!v) {
      v = (crypto?.randomUUID?.() || (Math.random().toString(16).slice(2) + Date.now().toString(16)));
      localStorage.setItem(CLIENT_KEY, v);
    }
    return v;
  } catch {
    return "anon";
  }
}
function getToken(): string | null {
  try { return localStorage.getItem(TOKEN_KEY); } catch { return null; }
}

export default function App() {
  const [text, setText] = useState("");
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [planStatus, setPlanStatus] = useState<PlanStatus | null>(null);
  const [isPro, setIsPro] = useState(false);

  const apiBase = (import.meta as any).env?.VITE_API_BASE_URL || "http://localhost:4000";

  const fillExample = () => {
    setError(null);
    setResult(null);
    setText(
      [
        "Me: I felt weird about last night.",
        "Them: Why? You're overthinking again.",
        "Me: You said you'd call and you didn't.",
        "Them: I was busy. Stop making problems.",
        "Me: I just want honesty.",
        "Them: I am honest. You're being dramatic."
      ].join("\n")
    );
  };

  async function refreshPlan() {
    try {
      const token = getToken();
      const res = await fetch(`${apiBase}/plan`, {
        headers: {
          "x-confusionai-client": getClientId(),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) return;
      const data = (await res.json()) as PlanStatus;
      setPlanStatus(data);
      setIsPro(data.plan === "pro");
    } catch { /* ignore */ }
  }

  useEffect(() => { refreshPlan(); /* eslint-disable-next-line */ }, []);

  // Compatibility score (0-100)
  const compatibility = useMemo(() => {
    if (!result) return 0;

    const honesty = num(result.honesty?.score);
    const inLove = num(result.inLove?.score);
    const flirting = num(result.flirting?.score);
    const shy = num(result.shy?.score);

    const gas = num(result.gaslighting?.score);
    const hidden = num(result.hiddenAgenda?.score);
    const misc = num(result.miscommunication?.score);

    const positives = (honesty * 0.55) + (inLove * 0.25) + (flirting * 0.10) + (shy * 0.10);
    const negatives = (gas * 0.45) + (hidden * 0.30) + (misc * 0.25);

    return clamp(Math.round((positives + (100 - negatives)) / 2), 0, 100);
  }, [result]);

  const compatibilityLabel = useMemo(() => {
    if (compatibility >= 78) return "Strong";
    if (compatibility >= 55) return "Mixed";
    return "Toxic";
  }, [compatibility]);

  // Background color shifts based on key metrics (no pulsing)
  const bgStyle = useMemo(() => {
    if (!result) {
      return {
        background:
          "radial-gradient(900px circle at 20% 10%, rgba(34,211,238,0.12), transparent 55%), radial-gradient(900px circle at 80% 0%, rgba(236,72,153,0.10), transparent 50%), linear-gradient(180deg, rgb(2,6,23), rgb(2,6,23))",
      } as React.CSSProperties;
    }

    const redIntensity = clamp(
      (num(result.gaslighting?.score) + num(result.hiddenAgenda?.score) + num(result.miscommunication?.score)) / 300,
      0,
      1
    );
    const greenIntensity = clamp(num(result.honesty?.score) / 100, 0, 1);
    const blueIntensity = clamp(num(result.inLove?.score) / 100, 0, 1);

    const r = Math.round(30 + 200 * redIntensity);
    const g = Math.round(25 + 190 * greenIntensity);
    const b = Math.round(40 + 200 * blueIntensity);

    return {
      background:
        `radial-gradient(1100px circle at 15% 5%, rgba(${r},${g},${b},0.22), transparent 58%),` +
        `radial-gradient(900px circle at 80% 0%, rgba(${b},${g},${r},0.14), transparent 55%),` +
        `linear-gradient(180deg, rgb(2,6,23), rgb(2,6,23))`,
    } as React.CSSProperties;
  }, [result]);

  // Accent ring on the main input container (Google-bar focal)
  const inputAccentClass = useMemo(() => {
    if (!result) return "border-slate-700/70 ring-cyan-400/20";
    if (compatibility >= 78) return "border-blue-400/40 ring-blue-400/25";
    if (compatibility >= 55) return "border-cyan-400/40 ring-cyan-400/25";
    return "border-red-400/40 ring-red-400/25";
  }, [compatibility, result]);

  const planPillLabel = useMemo(() => {
    if (isPro) return "Pro: unlimited";
    const used = planStatus?.usedToday ?? 0;
    const limit = planStatus?.freeDailyLimit ?? 5;
    return `Free: ${used}/${limit} today`;
  }, [isPro, planStatus]);

  const planPillClass = isPro
    ? "border-cyan-400/40 text-cyan-200 bg-cyan-500/10"
    : "border-emerald-400/40 text-emerald-200 bg-emerald-500/10";

  async function handleAnalyzeText() {
    if (!text.trim()) {
      setError("Paste a conversation first.");
      return;
    }

    setBusy(true);
    setError(null);
    setResult(null);

    try {
      const token = getToken();
      const res = await fetch(`${apiBase}/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-confusionai-client": getClientId(),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ text }),
      });

      if (res.status === 402) {
        const body = await res.json().catch(() => null);
        const used = body?.usedToday ?? planStatus?.usedToday ?? 5;
        const limit = body?.freeDailyLimit ?? planStatus?.freeDailyLimit ?? 5;
        setError(`Free limit reached (${used}/${limit}). Tap Upgrade for unlimited.`);
        await refreshPlan();
        return;
      }

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Text analysis failed with ${res.status}`);
      }

      const data = (await res.json()) as AnalysisResult;
      setResult(data);
      await refreshPlan();
    } catch (e: any) {
      setError(e?.message || "Unexpected error.");
      console.error(e);
    } finally {
      setBusy(false);
    }
  }

  // Stripe not wired until you create price_...
  function handleUpgradeClick() {
    setError("Stripe not finished yet. Create a Stripe price (price_...) and we’ll wire checkout.");
  }

  const renderMetric = (label: string, metric?: Metric) => {
    if (!metric) return null;
    const score = clamp(num(metric.score), 0, 100);
    return (
      <div className="rounded-2xl border border-slate-700/70 bg-slate-900/55 p-3">
        <div className="flex items-center justify-between text-xs font-semibold text-slate-100">
          <span>{label}</span>
          <span className="text-emerald-300">{score}/100</span>
        </div>
        {!!metric.reason && <p className="mt-1 text-xs text-slate-300">{metric.reason}</p>}
      </div>
    );
  };

  return (
    <div className="relative min-h-screen text-slate-50 transition-colors duration-700" style={bgStyle}>
      <div className="mx-auto flex max-w-5xl flex-col gap-4 px-4 py-6">
        <header className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-500 bg-clip-text text-3xl font-bold tracking-tight text-transparent">
              Confusion-AI
            </h1>
            <p className="text-xs text-slate-300/80">
              Paste a chat or upload a screenshot. The page colors shift with the mood.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span className={`rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${planPillClass}`}>
              {planPillLabel}
            </span>
            <button
              type="button"
              onClick={handleUpgradeClick}
              className="rounded-full border border-fuchsia-500/30 bg-fuchsia-500/10 px-3 py-2 text-[10px] font-semibold uppercase tracking-wide text-fuchsia-200 hover:bg-fuchsia-500/15"
            >
              Upgrade
            </button>
            <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-200">
              Innovative Solutions
            </span>
          </div>
        </header>

        <OnboardingPanel onFillExample={fillExample} />

        {/* FOCAL INPUT CONTAINER (Paste + Upload + Analyze) */}
        <section
          className={[
            "mx-auto w-full max-w-4xl rounded-[28px] border bg-slate-950/45 p-4 sm:p-5 shadow-2xl",
            "ring-1",
            inputAccentClass,
          ].join(" ")}
        >
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-sm font-semibold text-slate-100">Drop the conversation here</h2>
              <p className="text-xs text-slate-300/80">
                Paste text or upload a screenshot. Then hit Analyze.
              </p>
            </div>
            <span className="inline-flex items-center rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-200">
              Compatibility: {compatibilityLabel} • {compatibility}/100
            </span>
          </div>

          {/* Google-like “search bar” input */}
          <div
            className={[
              "mt-3 rounded-[999px] border bg-slate-950/55 px-4 py-3 shadow-lg",
              "ring-1",
              inputAccentClass,
            ].join(" ")}
          >
            <div className="flex items-start gap-3">
              <div className="mt-1 select-none text-slate-300/80">💬</div>

              <textarea
                className="min-h-[56px] w-full resize-none bg-transparent text-sm text-slate-100 outline-none placeholder:text-slate-500"
                placeholder="Paste a text conversation here… (Example: Me: … / Them: …)"
                value={text}
                onChange={(e) => setText(e.target.value)}
              />

              <button
                type="button"
                onClick={handleAnalyzeText}
                disabled={busy}
                className="shrink-0 rounded-full bg-emerald-500 px-5 py-3 text-xs font-semibold text-slate-950 shadow-lg shadow-emerald-900/40 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {busy ? "Analyzing…" : "Analyze"}
              </button>
            </div>
          </div>

          {error && <div className="mt-2 text-xs text-red-300">{error}</div>}

          {/* Screenshot upload inside SAME container */}
          <div className="mt-4 rounded-2xl border border-slate-700/70 bg-slate-900/35 p-3">
            <div className="mb-2 flex items-center justify-between">
              <span className="text-xs font-semibold text-slate-100">Or upload a screenshot</span>
              <span className="text-[11px] text-slate-400">PNG/JPG • best results with clear text</span>
            </div>

            <ScreenshotUpload
              onResult={(data: any) => {
                setResult(data as AnalysisResult);
                setError(null);
                refreshPlan();
              }}
              onError={(msg: string) => setError(msg)}
            />
          </div>
        </section>

        {/* RESULTS */}
        <section className="mt-2 grid gap-4 md:grid-cols-2">
          <div className="rounded-3xl border border-slate-700/70 bg-slate-950/45 p-4">
            <h3 className="text-sm font-semibold text-slate-100">Summary</h3>
            {!result?.summary ? (
              <p className="mt-2 text-xs text-slate-300/80">Run an analysis to get a summary.</p>
            ) : (
              <p className="mt-2 text-xs text-slate-200">{result.summary}</p>
            )}
          </div>

          <div className="rounded-3xl border border-slate-700/70 bg-slate-950/45 p-4">
            <h3 className="text-sm font-semibold text-slate-100">Breakdown</h3>
            {!result ? (
              <p className="mt-2 text-xs text-slate-300/80">Metrics show up after analysis.</p>
            ) : (
              <div className="mt-3 grid gap-2 sm:grid-cols-2">
                {renderMetric("Honesty", result.honesty)}
                {renderMetric("Gaslighting", result.gaslighting)}
                {renderMetric("Hidden agenda", result.hiddenAgenda)}
                {renderMetric("Miscommunication", result.miscommunication)}
                {renderMetric("In love", result.inLove)}
                {renderMetric("Flirting", result.flirting)}
                {renderMetric("Shy", result.shy)}
              </div>
            )}
          </div>
        </section>
      </div>

      <BrandWatermark />
    </div>
  );
}
'@

Write-Utf8NoBom $appPath $app
Write-Host "Wrote: frontend/src/App.tsx" -ForegroundColor Green

# Build check
Push-Location $frontendPath
Write-Host "npm install --include=dev" -ForegroundColor Yellow
npm install --include=dev
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

Write-Host "npm run build" -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location

if ($exit -ne 0) {
  Write-Error "Build failed. Paste the FIRST 20 lines of the error."
  exit 1
}

Write-Host "✅ Build OK. Now git add/commit/push." -ForegroundColor Cyan
