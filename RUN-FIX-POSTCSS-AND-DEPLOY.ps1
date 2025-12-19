param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend",
  [string]$Branch = "main",
  [switch]$SkipGitPush
)

Write-Host "=== Confusion-AI: Fix PostCSS/Tailwind + Build + Push ===" -ForegroundColor Cyan

# Resolve repo root
try { $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend directory not found: $frontendPath"; exit 1 }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_frontend_postcss_tailwind_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null
Write-Host "Backup folder: $backupDir" -ForegroundColor DarkGray

function Backup-IfExists($path) {
  if (Test-Path $path) {
    $name = Split-Path $path -Leaf
    Copy-Item $path (Join-Path $backupDir $name) -Force
    Write-Host "Backed up: $name" -ForegroundColor DarkGray
  }
}

# Potential PostCSS config files
$postcssCandidates = @(
  (Join-Path $frontendPath "postcss.config.cjs"),
  (Join-Path $frontendPath "postcss.config.js"),
  (Join-Path $frontendPath "postcss.config.mjs"),
  (Join-Path $frontendPath "postcss.config.json"),
  (Join-Path $frontendPath ".postcssrc"),
  (Join-Path $frontendPath ".postcssrc.json"),
  (Join-Path $frontendPath ".postcssrc.js"),
  (Join-Path $frontendPath ".postcssrc.cjs")
)

$tailwindConfig = Join-Path $frontendPath "tailwind.config.cjs"
$mainTsx        = Join-Path $frontendPath "src\main.tsx"
$indexCss       = Join-Path $frontendPath "src\index.css"

# Backups
$postcssCandidates | ForEach-Object { Backup-IfExists $_ }
Backup-IfExists $tailwindConfig
Backup-IfExists $mainTsx
Backup-IfExists $indexCss

# Disable stray JSON-style PostCSS configs
$postcssDisable = @(
  (Join-Path $frontendPath ".postcssrc"),
  (Join-Path $frontendPath ".postcssrc.json"),
  (Join-Path $frontendPath "postcss.config.json")
)

foreach ($f in $postcssDisable) {
  if (Test-Path $f) {
    $bak = "$f.bak-$timestamp"
    Move-Item $f $bak -Force
    Write-Host "Disabled: $(Split-Path $f -Leaf) -> $(Split-Path $bak -Leaf)" -ForegroundColor Yellow
  }
}

# Write clean postcss.config.cjs (CJS, no BOM)
$postcssPath = Join-Path $frontendPath "postcss.config.cjs"
$postcssContent = @"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
"@
Set-Content -Path $postcssPath -Value $postcssContent -Encoding UTF8
Write-Host "Wrote: frontend/postcss.config.cjs" -ForegroundColor Green

# Write clean tailwind.config.cjs
$tailwindContent = @"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
"@
Set-Content -Path $tailwindConfig -Value $tailwindContent -Encoding UTF8
Write-Host "Wrote: frontend/tailwind.config.cjs" -ForegroundColor Green

# Ensure Tailwind CSS file exists
New-Item -ItemType Directory -Path (Split-Path $indexCss -Parent) -ErrorAction SilentlyContinue | Out-Null
$cssContent = @"
@tailwind base;
@tailwind components;
@tailwind utilities;
"@
Set-Content -Path $indexCss -Value $cssContent -Encoding UTF8
Write-Host "Wrote: frontend/src/index.css" -ForegroundColor Green

# Ensure main.tsx imports index.css
if (Test-Path $mainTsx) {
  $mainRaw = Get-Content $mainTsx -Raw
  if ($mainRaw -notmatch "import\s+['""]\.\/index\.css['""];") {
    # Put import at top
    $patched = "import './index.css';`r`n" + $mainRaw
    Set-Content -Path $mainTsx -Value $patched -Encoding UTF8
    Write-Host "Patched: frontend/src/main.tsx (added CSS import)" -ForegroundColor Green
  } else {
    Write-Host "frontend/src/main.tsx already imports ./index.css" -ForegroundColor DarkGray
  }
} else {
  Write-Host "WARNING: frontend/src/main.tsx not found; cannot add CSS import." -ForegroundColor Yellow
}

# Install deps (idempotent)
Write-Host "Installing Tailwind/PostCSS deps..." -ForegroundColor Yellow
Push-Location $frontendPath
npm install -D tailwindcss postcss autoprefixer
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

# Build locally to confirm
Write-Host "Running frontend build locally (npm run build)..." -ForegroundColor Yellow
npm run build
$buildExit = $LASTEXITCODE
Pop-Location

if ($buildExit -ne 0) {
  Write-Error "Local build still failing. STOP. Paste the first ~30 lines of the error here."
  Write-Host "Backup folder: $backupDir" -ForegroundColor DarkGray
  exit 1
}

Write-Host "✅ Local build succeeded." -ForegroundColor Green

if ($SkipGitPush) {
  Write-Host "SkipGitPush enabled. Not committing/pushing." -ForegroundColor Yellow
  exit 0
}

# Git commit + push (only if there are changes)
Write-Host "Checking git status..." -ForegroundColor Yellow
git status

$changes = git status --porcelain
if (-not $changes) {
  Write-Host "No changes to commit. You're already clean." -ForegroundColor DarkGray
  exit 0
}

Write-Host "Committing + pushing to origin/$Branch..." -ForegroundColor Yellow
git add frontend/postcss.config.cjs frontend/tailwind.config.cjs frontend/src/index.css frontend/src/main.tsx
git commit -m "Fix PostCSS/Tailwind config for Vercel build"
git push origin $Branch

Write-Host "=== Done. Now go to Vercel and hit Redeploy (or it auto-deploys). ===" -ForegroundColor Cyan
