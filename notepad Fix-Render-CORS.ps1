# Fix-Render-CORS.ps1
# ✅ What this does (idempotent):
# 1) Finds your backend entry (backend/index.js or backend/server.js)
# 2) Installs "cors" in /backend
# 3) Injects a CORS middleware block (supports Vercel + preview + localhost + OPTIONS preflight)
# 4) (Optional) Adds /health endpoint if missing
# 5) (Optional) Creates frontend/.env.local with VITE_API_BASE_URL (for local testing)
# 6) (Optional) Tries to git add/commit/push (safe if it fails; it will print next steps)
#
# ✅ Run from REPO ROOT (folder containing /backend and /frontend)
#
# USAGE:
#   powershell -ExecutionPolicy Bypass -File .\Fix-Render-CORS.ps1
#   powershell -ExecutionPolicy Bypass -File .\Fix-Render-CORS.ps1 -AlsoWriteFrontendEnv
#   powershell -ExecutionPolicy Bypass -File .\Fix-Render-CORS.ps1 -AlsoWriteFrontendEnv -TryPush

param(
  [switch]$AlsoWriteFrontendEnv,
  [switch]$TryPush,
  [string]$ApiBaseUrl = "https://auraai-live.onrender.com"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBomFile {
  param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)][string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Backup-FileIfExists {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (Test-Path $Path) {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $bak = "$Path.bak_$ts"
    Copy-Item $Path $bak -Force
    Write-Host "🧷 Backup created: $bak"
  }
}

function Get-NpmCmd {
  try { & npm --version | Out-Null; return "npm" } catch { return "npm.cmd" }
}

function Ensure-InsertedAfterLine {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][string]$PatternLineRegex,
    [Parameter(Mandatory=$true)][string]$InsertBlock,
    [Parameter(Mandatory=$true)][string]$MarkerRegex
  )

  if ($Text -match $MarkerRegex) { return $Text }

  $m = [Regex]::Match($Text, $PatternLineRegex, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if (-not $m.Success) { return $null }

  $idx = $m.Index + $m.Length
  return $Text.Insert($idx, "`r`n`r`n" + $InsertBlock.Trim() + "`r`n")
}

# --- Validate repo structure ---
$root = (Get-Location).Path
$backendDir = Join-Path $root "backend"
$frontendDir = Join-Path $root "frontend"

if (!(Test-Path $backendDir)) { throw "Couldn't find /backend. Run this from your repo root." }
if (!(Test-Path $frontendDir)) { Write-Host "⚠️ /frontend not found (ok). Skipping frontend env step unless present." }

# --- Find backend entry file ---
$entryCandidates = @(
  (Join-Path $backendDir "index.js"),
  (Join-Path $backendDir "server.js")
)
$entry = $entryCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $entry) { throw "Couldn't find backend entry. Expected backend/index.js or backend/server.js" }

Write-Host "✅ Backend entry: $entry"

# --- Install cors dependency ---
$npm = Get-NpmCmd
Push-Location $backendDir
try {
  Write-Host "📦 Installing cors in /backend ..."
  & $npm i cors | Out-Host
} finally {
  Pop-Location
}

# --- Patch backend entry for CORS ---
Backup-FileIfExists -Path $entry
$txt = Get-Content -Raw -Path $entry

# 1) Ensure cors require exists
if ($txt -notmatch 'require\(["'']cors["'']\)') {
  # Put it near the top with other requires
  if ($txt -match '(?m)^(const|let|var)\s+express\s*=\s*require\(["'']express["'']\)\s*;') {
    $txt = [Regex]::Replace(
      $txt,
      '(?m)^(const|let|var)\s+express\s*=\s*require\(["'']express["'']\)\s*;\s*$',
      '$0' + "`r`n" + 'const cors = require("cors");'
    )
  } else {
    $txt = 'const cors = require("cors");' + "`r`n" + $txt
  }
}

# 2) Insert CORS middleware after app initialization
$corsBlock = @"
 /**
  * CORS (Vercel + local dev)
  * Fixes: "blocked by CORS policy" + preflight OPTIONS failures
  */
 const allowedOrigins = [
   "https://confusion-ai.vercel.app",
   "http://localhost:5173",
   "http://localhost:5174",
 ];

 const corsOptions = {
   origin: function (origin, cb) {
     // allow server-to-server / curl (no Origin header)
     if (!origin) return cb(null, true);

     // allow exact matches
     if (allowedOrigins.includes(origin)) return cb(null, true);

     // allow Vercel preview domains like https://confusion-ai-git-xxxx.vercel.app
     if (/^https:\/\/confusion-ai(-.*)?\.vercel\.app$/.test(origin)) return cb(null, true);

     return cb(new Error("CORS blocked for origin: " + origin));
   },
   methods: ["GET", "POST", "OPTIONS"],
   allowedHeaders: ["Content-Type", "Authorization", "x-confusionai-client"],
   credentials: false,
   maxAge: 86400,
 };

 app.use(cors(corsOptions));
 app.options("*", cors(corsOptions));
"@

# Detect common app init patterns
$appInitRegex = '(?m)^(const|let|var)\s+app\s*=\s*express\(\)\s*;\s*$'
$markerRegex = '(?m)CORS\s*\(Vercel\s*\+\s*local\s*dev\)'

$patched = Ensure-InsertedAfterLine -Text $txt -PatternLineRegex $appInitRegex -InsertBlock $corsBlock -MarkerRegex $markerRegex
if ($null -eq $patched) {
  Write-Host "⚠️ Could not find the line: const app = express();"
  Write-Host "   Add the CORS block manually right after your app initialization."
} else {
  $txt = $patched
  Write-Host "✅ CORS middleware injected."
}

# 3) Optional: add /health route if missing (nice for testing)
if ($txt -notmatch '(?m)app\.get\(["'']\/health["'']') {
  $healthBlock = @"
app.get("/health", (req, res) => res.json({ ok: true }));
"@
  # Insert near other routes if we can find "app.listen" to put above it
  if ($txt -match '(?m)^\s*app\.listen\(') {
    $txt = [Regex]::Replace($txt, '(?m)^\s*app\.listen\(', $healthBlock + "`r`n" + 'app.listen(')
    Write-Host "✅ Added /health endpoint."
  } else {
    # If no listen found, skip quietly
    Write-Host "ℹ️ app.listen not found; skipping /health insertion."
  }
}

Write-Utf8NoBomFile -Path $entry -Content $txt
Write-Host "✅ Saved: $entry"

# --- Optional: write frontend/.env.local for local testing ---
if ($AlsoWriteFrontendEnv -and (Test-Path $frontendDir)) {
  $envPath = Join-Path $frontendDir ".env.local"
  $envContent = "VITE_API_BASE_URL=$ApiBaseUrl`r`n"
  Backup-FileIfExists -Path $envPath
  Write-Utf8NoBomFile -Path $envPath -Content $envContent
  Write-Host "✅ Wrote: $envPath"
  Write-Host "   (This affects local dev builds only. Vercel env vars are set in Vercel UI.)"
}

# --- Optional: git add/commit/push ---
if ($TryPush) {
  try {
    Write-Host "🧾 Attempting git add/commit/push..."
    & git rev-parse --is-inside-work-tree | Out-Null

    & git add backend | Out-Null
    if ($AlsoWriteFrontendEnv -and (Test-Path $frontendDir)) { & git add frontend/.env.local | Out-Null }

    $status = & git status --porcelain
    if (-not $status) {
      Write-Host "ℹ️ No changes to commit."
    } else {
      & git commit -m "Enable CORS for Vercel + add health route" | Out-Host
      & git push | Out-Host
      Write-Host "✅ Pushed to GitHub. Render should auto-redeploy."
    }
  } catch {
    Write-Host "⚠️ Git push attempt failed (not fatal). Do it manually:"
    Write-Host "   git add ."
    Write-Host "   git commit -m `"Enable CORS for Vercel`""
    Write-Host "   git push"
  }
}

Write-Host ""
Write-Host "✅ DONE."
Write-Host ""
Write-Host "NEXT (IMPORTANT):"
Write-Host "1) Set Vercel env var (manual):"
Write-Host "   Vercel → Project → Settings → Environment Variables"
Write-Host "   Add/Update: VITE_API_BASE_URL = $ApiBaseUrl"
Write-Host "   Then redeploy."
Write-Host ""
Write-Host "2) Verify backend endpoints:"
Write-Host "   $ApiBaseUrl/health  (should return { ok: true })"
Write-Host "   $ApiBaseUrl/plan"
Write-Host ""
Write-Host "3) Verify frontend:"
Write-Host "   https://confusion-ai.vercel.app should call Render without CORS errors."
