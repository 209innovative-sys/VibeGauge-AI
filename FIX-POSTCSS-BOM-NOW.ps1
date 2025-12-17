param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== FIX PostCSS JSON/BOM issue (Confusion-AI) ===" -ForegroundColor Cyan

function Write-Utf8NoBom {
  param([string]$Path, [string]$Content)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# Resolve repo root
try { $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend directory not found: $frontendPath"; exit 1 }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_postcss_bom_fix_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null
Write-Host "Backup dir: $backupDir" -ForegroundColor DarkGray

function Backup-IfExists($path) {
  if (Test-Path $path) {
    Copy-Item $path (Join-Path $backupDir (Split-Path $path -Leaf)) -Force
  }
}

# Files that commonly cause Vite to load JSON PostCSS config
$badJsonConfigs = @(
  (Join-Path $frontendPath ".postcssrc"),
  (Join-Path $frontendPath ".postcssrc.json"),
  (Join-Path $frontendPath "postcss.config.json")
)

foreach ($f in $badJsonConfigs) {
  if (Test-Path $f) {
    Backup-IfExists $f
    $disabled = "$f.disabled-$timestamp"
    Move-Item $f $disabled -Force
    Write-Host "Disabled: $(Split-Path $f -Leaf) -> $(Split-Path $disabled -Leaf)" -ForegroundColor Yellow
  }
}

# Also scan for any other postcssrc/postcss json files anywhere under frontend
Get-ChildItem -Path $frontendPath -Recurse -Force -File |
  Where-Object { $_.Name -match '^\.postcssrc' -or $_.Name -ieq 'postcss.config.json' } |
  ForEach-Object {
    if ($badJsonConfigs -notcontains $_.FullName) {
      Backup-IfExists $_.FullName
      $disabled = "$($_.FullName).disabled-$timestamp"
      Move-Item $_.FullName $disabled -Force
      Write-Host "Disabled: $($_.FullName.Replace($frontendPath,'frontend'))" -ForegroundColor Yellow
    }
  }

# Write a clean PostCSS config (CJS) WITHOUT BOM
$postcssPath = Join-Path $frontendPath "postcss.config.cjs"
Backup-IfExists $postcssPath

$postcssContent = @"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
"@
Write-Utf8NoBom -Path $postcssPath -Content $postcssContent
Write-Host "Wrote: frontend/postcss.config.cjs (no BOM)" -ForegroundColor Green

# Ensure Tailwind config exists (no BOM) – safe
$tailwindPath = Join-Path $frontendPath "tailwind.config.cjs"
Backup-IfExists $tailwindPath

$tailwindContent = @"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: { extend: {} },
  plugins: [],
};
"@
Write-Utf8NoBom -Path $tailwindPath -Content $tailwindContent
Write-Host "Wrote: frontend/tailwind.config.cjs (no BOM)" -ForegroundColor Green

# Ensure Tailwind CSS entry exists + main.tsx imports it (no BOM)
$indexCss = Join-Path $frontendPath "src\index.css"
$mainTsx  = Join-Path $frontendPath "src\main.tsx"

New-Item -ItemType Directory -Path (Split-Path $indexCss -Parent) -ErrorAction SilentlyContinue | Out-Null
$cssContent = "@tailwind base;`r`n@tailwind components;`r`n@tailwind utilities;`r`n"
Write-Utf8NoBom -Path $indexCss -Content $cssContent
Write-Host "Wrote: frontend/src/index.css (no BOM)" -ForegroundColor Green

if (Test-Path $mainTsx) {
  $raw = Get-Content $mainTsx -Raw
  if ($raw -notmatch "import\s+['""]\.\/index\.css['""];") {
    $patched = "import './index.css';`r`n" + $raw
    Write-Utf8NoBom -Path $mainTsx -Content $patched
    Write-Host "Patched: frontend/src/main.tsx (added css import, no BOM)" -ForegroundColor Green
  } else {
    Write-Host "frontend/src/main.tsx already imports ./index.css" -ForegroundColor DarkGray
  }
}

# Install deps + build test
Push-Location $frontendPath
Write-Host "Installing deps..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

Write-Host "Running local build (npm run build)..." -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location

if ($exit -ne 0) {
  Write-Error "Build still failed. Paste the FIRST 40 lines of the error."
  exit 1
}

Write-Host "✅ Local build succeeded." -ForegroundColor Green
Write-Host "Next: commit + push, then redeploy on Vercel." -ForegroundColor Cyan
