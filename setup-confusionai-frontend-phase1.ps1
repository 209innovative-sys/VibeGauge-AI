param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== Confusion-AI Frontend Phase 1 Setup ===" -ForegroundColor Cyan

# Resolve repo root and move there
try {
  $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
}
catch {
  Write-Error "Repo root not found: $RepoRoot"
  exit 1
}

Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

# Resolve frontend path
$frontendPath = Join-Path $rootPath $FrontendDir
if (-not (Test-Path $frontendPath)) {
  Write-Error "Frontend directory not found at: $frontendPath"
  exit 1
}

Write-Host "Frontend path: $frontendPath" -ForegroundColor Yellow

$pkgPath = Join-Path $frontendPath "package.json"
if (-not (Test-Path $pkgPath)) {
  Write-Warning "No package.json found in frontend. Vite/React may not be installed, but continuing file setup."
}
else {
  Write-Host "Found frontend package.json at: $pkgPath" -ForegroundColor Green
}

# Backup existing src
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_frontend_confusionai_phase1_" + $timestamp)

$srcPath = Join-Path $frontendPath "src"
if (Test-Path $srcPath) {
  Write-Host "Backing up frontend src to: $backupDir" -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null
  Copy-Item -Path $srcPath -Destination $backupDir -Recurse -Force
  Write-Host "Backup complete." -ForegroundColor Green
}
else {
  Write-Warning "No src directory found at: $srcPath. Creating it."
  New-Item -ItemType Directory -Path $srcPath -ErrorAction SilentlyContinue | Out-Null
}

# Ensure components directory
$componentsDir = Join-Path $srcPath "components"
if (-not (Test-Path $componentsDir)) {
  New-Item -ItemType Directory -Path $componentsDir -ErrorAction SilentlyContinue | Out-Null
  Write-Host "Created components directory at: $componentsDir" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# Write App.tsx
# ---------------------------------------------------------------------
$appPath = Join-Path $srcPath "App.tsx"
Write-Host "Writing App.tsx to: $appPath" -ForegroundColor Yellow

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
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

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
                setError(message || null);
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
Write-Host "App.tsx written." -ForegroundColor Green

# ---------------------------------------------------------------------
# Write BrandWatermark.tsx
# ---------------------------------------------------------------------
$brandPath = Join-Path $componentsDir "BrandWatermark.tsx"
Write-Host "Writing BrandWatermark.tsx to: $brandPath" -ForegroundColor Yellow

$brandContent = @'
import React from "react";

const BrandWatermark: React.FC = () => {
  return (
    <div className="pointer-events-none fixed inset-0 flex items-end justify-end px-4 py-3">
      <span className="select-none text-xs sm:text-sm font-semibold italic text-fuchsia-400/60 drop-shadow-[0_0_8px_rgba(236,72,153,0.8)]">
        Innovative Solutions
      </span>
    </div>
  );
};

export default BrandWatermark;
'@

Set-Content -Path $brandPath -Value $brandContent -Encoding UTF8
Write-Host "BrandWatermark.tsx written." -ForegroundColor Green

# ---------------------------------------------------------------------
# Write ScreenshotUpload.tsx
# ---------------------------------------------------------------------
$ssPath = Join-Path $componentsDir "ScreenshotUpload.tsx"
Write-Host "Writing ScreenshotUpload.tsx to: $ssPath" -ForegroundColor Yellow

$ssContent = @'
import React, { useEffect, useState } from "react";

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

type ScreenshotUploadProps = {
  onResult: (result: AnalysisResult) => void;
  onError: (message: string) => void;
};

const ScreenshotUpload: React.FC<ScreenshotUploadProps> = ({
  onResult,
  onError,
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);

  const apiBase =
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = e.target.files?.[0];
    if (!selected) return;

    if (!selected.type.startsWith("image/")) {
      const msg = "Please select a PNG or JPEG screenshot.";
      setLocalError(msg);
      onError(msg);
      setFile(null);
      setPreviewUrl(null);
      return;
    }

    setFile(selected);
    setLocalError(null);
    const url = URL.createObjectURL(selected);
    setPreviewUrl(url);
  };

  const handleUpload = async () => {
    if (!file) {
      const msg = "Choose a screenshot first.";
      setLocalError(msg);
      onError(msg);
      return;
    }

    setIsUploading(true);
    setLocalError(null);
    onError("");

    try {
      const formData = new FormData();
      formData.append("image", file);

      const res = await fetch(`${apiBase}/analyze-image`, {
        method: "POST",
        body: formData,
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(
          body || `Screenshot analysis failed with ${res.status}`
        );
      }

      const data = (await res.json()) as AnalysisResult;
      onResult(data);
    } catch (err: unknown) {
      const message =
        err instanceof Error
          ? err.message
          : "Unexpected screenshot analysis error.";
      setLocalError(message);
      onError(message);
      console.error(err);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="mt-4 space-y-2 rounded-2xl border border-slate-700 bg-slate-950/60 p-3">
      <div className="flex items-center justify-between gap-2">
        <span className="text-xs font-semibold text-slate-200">
          Or upload a screenshot
        </span>
        <button
          type="button"
          onClick={handleUpload}
          disabled={isUploading || !file}
          className="inline-flex items-center justify-center rounded-lg bg-fuchsia-500 px-3 py-1.5 text-[11px] font-semibold text-slate-950 shadow-md shadow-fuchsia-900/40 transition hover:bg-fuchsia-400 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isUploading ? "Analyzing..." : "Analyze Screenshot"}
        </button>
      </div>

      <label className="flex cursor-pointer flex-col items-center justify-center rounded-xl border border-dashed border-slate-600 bg-slate-900/60 px-3 py-4 text-center text-[11px] text-slate-400 hover:border-fuchsia-500/70 hover:text-fuchsia-300">
        <input
          type="file"
          accept="image/png,image/jpeg"
          className="hidden"
          onChange={handleFileChange}
        />
        <span className="font-medium">
          Click to choose a PNG or JPEG conversation screenshot
        </span>
        <span className="mt-1 text-[10px] text-slate-500">
          We only use it to analyze this vibe. Nothing is stored.
        </span>
      </label>

      {previewUrl && (
        <div className="overflow-hidden rounded-xl border border-slate-700 bg-slate-900/70">
          <img
            src={previewUrl}
            alt="Conversation preview"
            className="max-h-64 w-full object-cover"
          />
        </div>
      )}

      {localError && (
        <p className="text-[11px] text-red-400">{localError}</p>
      )}
    </div>
  );
};

export default ScreenshotUpload;
'@

Set-Content -Path $ssPath -Value $ssContent -Encoding UTF8
Write-Host "ScreenshotUpload.tsx written." -ForegroundColor Green

# ---------------------------------------------------------------------
# Ensure frontend .env has VITE_API_BASE_URL
# ---------------------------------------------------------------------
$frontendEnvPath = Join-Path $frontendPath ".env"
Write-Host "Ensuring frontend .env contains VITE_API_BASE_URL..." -ForegroundColor Yellow

if (Test-Path $frontendEnvPath) {
  $envBackupDir = Join-Path $rootPath ("backup_frontend_env_" + $timestamp)
  New-Item -ItemType Directory -Path $envBackupDir -ErrorAction SilentlyContinue | Out-Null
  Copy-Item -Path $frontendEnvPath -Destination (Join-Path $envBackupDir ".env") -Force
  Write-Host "Existing .env backed up to: $envBackupDir" -ForegroundColor Green

  $existingLines = Get-Content -Path $frontendEnvPath -ErrorAction SilentlyContinue
  $filteredLines = @()
  foreach ($line in $existingLines) {
    if ($line -notmatch '^\s*VITE_API_BASE_URL\s*=') {
      $filteredLines += $line
    }
  }
  $filteredLines + 'VITE_API_BASE_URL=http://localhost:4000' |
  Set-Content -Path $frontendEnvPath -Encoding UTF8
}
else {
  'VITE_API_BASE_URL=http://localhost:4000' |
  Set-Content -Path $frontendEnvPath -Encoding UTF8
}

Write-Host "VITE_API_BASE_URL set for frontend." -ForegroundColor Green

Write-Host "=== Frontend Phase 1 setup complete. ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  cd `"$frontendPath`""
Write-Host "  npm install  (if not done yet)"
Write-Host "  npm run dev"
