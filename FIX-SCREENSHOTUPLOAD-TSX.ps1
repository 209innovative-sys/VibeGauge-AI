param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== Fix ScreenshotUpload.tsx (broken template strings) ===" -ForegroundColor Cyan

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

try { $root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
$frontendPath = Join-Path $root $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend folder not found: $frontendPath"; exit 1 }

$target = Join-Path $frontendPath "src\components\ScreenshotUpload.tsx"
if (-not (Test-Path $target)) { Write-Error "Missing: $target"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ("backup_screenshotupload_fix_" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $target (Join-Path $backupDir "ScreenshotUpload.tsx") -Force
Write-Host "Backup: $backupDir\ScreenshotUpload.tsx" -ForegroundColor DarkGray

$content = @'
import React, { useEffect, useMemo, useState } from "react";

type Props = {
  onResult: (data: any) => void;
  onError: (message: string) => void;
};

const TOKEN_KEY = "confusionai_pro_token";
const CLIENT_KEY = "confusionai_client_id";

function getClientId(): string {
  try {
    let v = localStorage.getItem(CLIENT_KEY);
    if (!v) {
      v =
        (crypto as any)?.randomUUID?.() ||
        Math.random().toString(16).slice(2) + Date.now().toString(16);
      localStorage.setItem(CLIENT_KEY, v);
    }
    return v;
  } catch {
    return "anon";
  }
}

function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export default function ScreenshotUpload({ onResult, onError }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const apiBase = (import.meta as any).env?.VITE_API_BASE_URL || "http://localhost:4000";

  const canAnalyze = useMemo(() => !!file && !busy, [file, busy]);

  useEffect(() => {
    if (!file) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  function handlePick(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0] || null;
    setFile(f);
  }

  async function handleAnalyze() {
    if (!file) {
      onError("Choose a screenshot first.");
      return;
    }

    setBusy(true);

    try {
      const formData = new FormData();
      // Backend expects "image"
      formData.append("image", file);

      const token = getToken();
      const res = await fetch(`${apiBase}/analyze-image`, {
        method: "POST",
        headers: {
          "x-confusionai-client": getClientId(),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: formData,
      });

      if (res.status === 402) {
        const body = await res.json().catch(() => null);
        const used = body?.usedToday ?? "?";
        const limit = body?.freeDailyLimit ?? "?";
        onError(`Free limit reached (${used}/${limit}). Tap Upgrade for unlimited.`);
        return;
      }

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Screenshot analysis failed with ${res.status}`);
      }

      const data = await res.json();
      onResult(data);
    } catch (e: any) {
      console.error(e);
      onError(e?.message || "Screenshot analyze failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="rounded-2xl border border-slate-700/70 bg-slate-950/40 p-3">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div className="text-xs font-semibold text-slate-100">Upload screenshot</div>
        <div className="text-[11px] text-slate-400">JPG/PNG • clear text works best</div>
      </div>

      <div className="mt-3 grid gap-3 sm:grid-cols-[1fr_auto] sm:items-center">
        <label className="block">
          <input
            type="file"
            accept="image/*"
            onChange={handlePick}
            className="block w-full cursor-pointer rounded-xl border border-slate-700 bg-slate-950/60 p-2 text-xs text-slate-200 file:mr-3 file:rounded-lg file:border-0 file:bg-slate-800 file:px-3 file:py-2 file:text-xs file:font-semibold file:text-slate-100 hover:file:bg-slate-700"
          />
        </label>

        <button
          type="button"
          disabled={!canAnalyze}
          onClick={handleAnalyze}
          className="rounded-xl bg-cyan-400 px-4 py-2 text-xs font-semibold text-slate-950 shadow-lg shadow-cyan-900/30 hover:bg-cyan-300 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {busy ? "Analyzing..." : "Analyze Screenshot"}
        </button>
      </div>

      {previewUrl && (
        <div className="mt-3 overflow-hidden rounded-xl border border-slate-700/70">
          <img src={previewUrl} alt="Screenshot preview" className="w-full max-h-64 object-contain bg-slate-950/40" />
        </div>
      )}
    </div>
  );
}
'@

Write-Utf8NoBom $target $content
Write-Host "Wrote: frontend/src/components/ScreenshotUpload.tsx" -ForegroundColor Green

# Build check
Push-Location $frontendPath
Write-Host "npm run build" -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location

if ($exit -ne 0) {
  Write-Error "Build still failing. Paste the FIRST 20 lines of the new error."
  exit 1
}

Write-Host "✅ Build OK. Now commit + push." -ForegroundColor Cyan

