param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend",
  [string]$Branch = "main",
  [switch]$SkipGitPush
)

Write-Host "=== Fix Vercel: vite command not found ===" -ForegroundColor Cyan

# Resolve repo root
try { $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend directory not found: $frontendPath"; exit 1 }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_vercel_vite_fix_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null

function Backup-IfExists($path) {
  if (Test-Path $path) {
    Copy-Item $path (Join-Path $backupDir (Split-Path $path -Leaf)) -Force
  }
}

$pkgPath   = Join-Path $frontendPath "package.json"
$lockPath  = Join-Path $frontendPath "package-lock.json"
$npmrcPath = Join-Path $frontendPath ".npmrc"
$nvmrcPath = Join-Path $frontendPath ".nvmrc"

Backup-IfExists $pkgPath
Backup-IfExists $lockPath
Backup-IfExists $npmrcPath
Backup-IfExists $nvmrcPath

# Force npm to install devDependencies even if NODE_ENV=production in Vercel
# This is the common reason Vite isn't present.
Set-Content -Path $npmrcPath -Value "production=false`n" -Encoding UTF8
Write-Host "Wrote frontend/.npmrc (production=false) to force devDependencies install." -ForegroundColor Green

# Pin Node for Vercel builds (safe default)
Set-Content -Path $nvmrcPath -Value "20`n" -Encoding UTF8
Write-Host "Wrote frontend/.nvmrc (20) for Vercel Node version." -ForegroundColor Green

# Ensure Vite exists in devDependencies + scripts are correct
if (-not (Test-Path $pkgPath)) { Write-Error "frontend/package.json missing"; exit 1 }
$jsonText = Get-Content -Path $pkgPath -Raw
$pkgJson  = $jsonText | ConvertFrom-Json

if (-not $pkgJson.scripts) { $pkgJson | Add-Member -NotePropertyName scripts -NotePropertyValue (@{}) -Force }
$pkgJson.scripts.dev     = "vite"
$pkgJson.scripts.build   = "vite build"
$pkgJson.scripts.preview = "vite preview"

# Write back package.json
$pkgJson | ConvertTo-Json -Depth 20 | Set-Content -Path $pkgPath -Encoding UTF8
Write-Host "Normalized frontend/package.json scripts (dev/build/preview)." -ForegroundColor Green

# Install deps and confirm vite exists
Push-Location $frontendPath

Write-Host "Installing dependencies (npm install)..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

Write-Host "Checking vite availability..." -ForegroundColor Yellow
npx vite --version
if ($LASTEXITCODE -ne 0) {
  Pop-Location
  Write-Error "Vite is still not available. Next step would be to install it explicitly."
  exit 1
}

Write-Host "Running local build (npm run build)..." -ForegroundColor Yellow
npm run build
$buildExit = $LASTEXITCODE
Pop-Location

if ($buildExit -ne 0) {
  Write-Error "Local build failed. Paste the first ~30 lines of the build error here."
  exit 1
}

Write-Host "✅ Local build succeeded." -ForegroundColor Green

if ($SkipGitPush) {
  Write-Host "SkipGitPush enabled. Not committing/pushing." -ForegroundColor Yellow
  exit 0
}

# Commit + push if changes exist
$changes = git status --porcelain
if (-not $changes) {
  Write-Host "No changes to commit." -ForegroundColor DarkGray
  exit 0
}

git add frontend/.npmrc frontend/.nvmrc frontend/package.json frontend/package-lock.json
git commit -m "Fix Vercel build: ensure devDependencies (vite) install"
git push origin $Branch

Write-Host "=== Done. Go to Vercel and Redeploy. ===" -ForegroundColor Cyan
Write-Host "Backup: $backupDir" -ForegroundColor DarkGray
