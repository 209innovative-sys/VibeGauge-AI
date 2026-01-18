param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== Confusion-AI: UI polish (instruction bubbles + sample chat) ===" -ForegroundColor Cyan

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
$backupDir = Join-Path $root ("backup_ui_bubbles_" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $appPath (Join-Path $backupDir "App.tsx") -Force
Write-Host "Backup: $backupDir\App.tsx" -ForegroundColor DarkGray

# 1) Create OnboardingPanel component
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

  return (
    <div
      className={[
        "relative rounded-3xl border p-4 text-sm",
        toneClasses,
        // little bubble tail
        "after:content-[''] after:absolute after:left-8 after:-bottom-3 after:border-[12px] after:border-x-transparent after:border-b-transparent",
        tone === "good"
          ? "after:border-t-emerald-500/10"
          : tone === "warn"
          ? "after:border-t-fuchsia-500/10"
          : "after:border-t-cyan-500/10",
      ].join(" ")}
    >
      <div className="text-xs font-semibold uppercase tracking-wide text-slate-100/90">
        {title}
      </div>
      <div className="mt-1 text-xs text-slate-200/80 leading-relaxed">
        {body}
      </div>
    </div>
  );
}

type Props = {
  onFillExample: () => void;
};

export default function OnboardingPanel({ onFillExample }: Props) {
  const [open, setOpen] = useState(true);

  const bullets = useMemo(
    () => [
      { t: "1) Paste or upload", b: "Choose ONE: paste a chat OR upload a screenshot.", tone: "info" as const },
      { t: "2) Hit Analyze", b: "Tap Analyze. Confusion-AI reads tone + patterns and returns a compatibility breakdown.", tone: "good" as const },
      { t: "3) Read the signals", b: "Honesty, gaslighting, hidden agenda, miscommunication, flirting, shy, inLove — plus a summary.", tone: "warn" as const },
    ],
    []
  );

  return (
    <section className="rounded-3xl border border-slate-700/70 bg-slate-900/40 p-4 sm:p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold text-slate-100">
            Quick start
          </h2>
          <p className="mt-1 text-xs text-slate-300">
            A little guide so new users don&apos;t feel lost.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onFillExample}
            className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-[11px] font-semibold text-emerald-200 hover:bg-emerald-500/15"
            title="Loads a sample conversation so users can demo instantly"
          >
            Try sample chat
          </button>

          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            className="rounded-xl border border-slate-700 bg-slate-950/40 px-3 py-2 text-[11px] font-semibold text-slate-200 hover:bg-slate-950/60"
          >
            {open ? "Hide" : "Show"}
          </button>
        </div>
      </div>

      {open && (
        <div className="mt-4 grid gap-3 md:grid-cols-3">
          {bullets.map((x) => (
            <Bubble key={x.t} title={x.t} body={x.b} tone={x.tone} />
          ))}
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
        <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1">
          Tip: include names like “Me:” and “Them:” for cleaner results.
        </span>
        <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1">
          Privacy: we don’t store your chats on the server in MVP mode.
        </span>
      </div>
    </section>
  );
}
'@
Write-Utf8NoBom $panelPath $panel
Write-Host "Wrote: frontend/src/components/OnboardingPanel.tsx" -ForegroundColor Green

# 2) Patch App.tsx (import + add fillExample + render panel)
$lines = Get-Content $appPath
$raw = Get-Content $appPath -Raw

# Insert import if missing
$importLine = 'import OnboardingPanel from "./components/OnboardingPanel";'
if ($raw -notmatch [regex]::Escape($importLine)) {
  $importIdx = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].TrimStart().StartsWith("import ") -and $lines[$i].TrimEnd().EndsWith(";")) { $importIdx = $i }
  }
  if ($importIdx -ge 0) {
    $newLines = @()
    $newLines += $lines[0..$importIdx]
    $newLines += $importLine
    if ($importIdx+1 -lt $lines.Count) { $newLines += $lines[($importIdx+1)..($lines.Count-1)] }
    $lines = $newLines
    $raw = ($lines -join "`r`n")
    Write-Host "Patched: added OnboardingPanel import" -ForegroundColor Green
  } else {
    Write-Host "WARNING: Could not locate import block to insert OnboardingPanel import." -ForegroundColor Yellow
  }
}

# Add fillExample function before apiBase definition if missing
if ($raw -notmatch "const\s+fillExample\s*=") {
  $sample = @"
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
"@

  # Insert right above "const apiBase"
  if ($raw -match "(\r?\n\s*const\s+apiBase\s*=)") {
    $raw = $raw -replace "(\r?\n\s*const\s+apiBase\s*=)", "`r`n$sample`r`n`$1"
    Write-Host "Patched: added fillExample()" -ForegroundColor Green
  } else {
    Write-Host "WARNING: Could not find apiBase block to insert fillExample()." -ForegroundColor Yellow
  }
}

# Render the panel right after </header> if not present
if ($raw -notmatch "<OnboardingPanel") {
  if ($raw -match "</header>") {
    $raw = $raw -replace "</header>", "</header>`r`n`r`n        <OnboardingPanel onFillExample={fillExample} />"
    Write-Host "Patched: added <OnboardingPanel /> after header" -ForegroundColor Green
  } else {
    Write-Host "WARNING: Could not find </header> to insert OnboardingPanel. Insert manually." -ForegroundColor Yellow
  }
}

Write-Utf8NoBom $appPath $raw
Write-Host "Updated: frontend/src/App.tsx" -ForegroundColor Cyan

# 3) Quick build check (optional but recommended)
Push-Location $frontendPath
Write-Host "Running: npm run build" -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location

if ($exit -ne 0) {
  Write-Error "Build failed. Fix the error then rerun this script."
  exit 1
}

Write-Host "✅ UI bubbles installed and build OK." -ForegroundColor Green
Write-Host "Next: git add/commit/push -> PR -> merge -> Vercel redeploy" -ForegroundColor Cyan
