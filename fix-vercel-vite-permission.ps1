param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend",
  [string]$Branch = "main",
  [switch]$SkipGitPush
)

Write-Host "=== Fix Vercel: vite permission denied (use node runner) ===" -ForegroundColor Cyan

function Write-Utf8NoBom {
  param([string]$Path, [string]$Content)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

try { $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend directory not found: $frontendPath"; exit 1 }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_vercel_vite_perm_fix_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null
Write-Host "Backup dir: $backupDir" -ForegroundColor DarkGray

function Backup-IfExists($path) {
  if (Test-Path $path) {
    Copy-Item $path (Join-Path $backupDir (Split-Path $path -Leaf)) -Force
  }
}

$pkgPath   = Join-Path $frontendPath "package.json"
$lockPath  = Join-Path $frontendPath "package-lock.json"
$npmrcPath = Join-Path $frontendPath ".npmrc"

Backup-IfExists $pkgPath
Backup-IfExists $lockPath
Backup-IfExists $npmrcPath

if (-not (Test-Path $pkgPath)) { Write-Error "frontend/package.json not found"; exit 1 }

# Force devDependencies install in Vercel builds
Write-Utf8NoBom -Path $npmrcPath -Content "production=false`n"
Write-Host "Wrote frontend/.npmrc (production=false)" -ForegroundColor Green

# Patch package.json scripts to avoid executing node_modules/.bin/vite
$jsonText = Get-Content -Path $pkgPath -Raw
$pkgJson  = $jsonText | ConvertFrom-Json

if (-not $pkgJson.scripts) { $pkgJson | Add-Member -MemberType NoteProperty -Name scripts -Value (@{}) -Force }

$pkgJson.scripts.dev     = "node ./node_modules/vite/bin/vite.js"
$pkgJson.scripts.build   = "node ./node_modules/vite/bin/vite.js build"
$pkgJson.scripts.preview = "node ./node_modules/vite/bin/vite.js preview"

$pkgOut = $pkgJson | ConvertTo-Json -Depth 30
Write-Utf8NoBom -Path $pkgPath -Content $pkgOut
Write-Host "Patched frontend/package.json scripts to use node runner for Vite" -ForegroundColor Green

# Local verify
Push-Location $frontendPath
Write-Host "npm install --include=dev" -ForegroundColor Yellow
npm install --include=dev
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

Write-Host "npm run build" -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location

if ($exit -ne 0) {
  Write-Error "Local build failed. Paste the FIRST 30 lines of the error."
  exit 1
}

Write-Host "✅ Local build succeeded." -ForegroundColor Cyan

if ($SkipGitPush) {
  Write-Host "SkipGitPush enabled. Not committing/pushing." -ForegroundColor Yellow
  exit 0
}

# Commit + push if needed
$porcelain = git status --porcelain
if (-not $porcelain) {
  Write-Host "No git changes detected to commit." -ForegroundColor DarkGray
  exit 0
}

git add frontend/package.json frontend/.npmrc frontend/package-lock.json
git commit -m "Fix Vercel build: run Vite via node (avoid .bin permission)"
git push origin $Branch

Write-Host "=== Done. Vercel should redeploy on this commit. ===" -ForegroundColor Cyan
