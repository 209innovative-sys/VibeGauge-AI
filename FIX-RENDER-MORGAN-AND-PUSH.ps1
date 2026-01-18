param(
  [string]$RepoRoot = ".",
  [string]$BackendDir = "backend"
)

Write-Host "=== Fix Render crash: install missing 'morgan' in backend deps + push branch ===" -ForegroundColor Cyan

function Abort($msg) {
  Write-Error $msg
  exit 1
}

try { $root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path } catch { Abort "Repo root not found: $RepoRoot" }
Set-Location $root

$backendPath = Join-Path $root $BackendDir
if (-not (Test-Path $backendPath)) { Abort "Backend folder not found: $backendPath" }

$pkg = Join-Path $backendPath "package.json"
$idx = Join-Path $backendPath "index.js"
if (-not (Test-Path $pkg)) { Abort "Missing backend/package.json" }
if (-not (Test-Path $idx)) { Abort "Missing backend/index.js" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ("backup_backend_morgan_fix_" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $pkg (Join-Path $backupDir "package.json") -Force
if (Test-Path (Join-Path $backendPath "package-lock.json")) {
  Copy-Item (Join-Path $backendPath "package-lock.json") (Join-Path $backupDir "package-lock.json") -Force
}
Copy-Item $idx (Join-Path $backupDir "index.js") -Force
Write-Host "Backup: $backupDir" -ForegroundColor DarkGray

# Install morgan as a production dependency (Render needs it at runtime)
Push-Location $backendPath
Write-Host "Installing backend dependency: morgan" -ForegroundColor Yellow
npm install morgan --save
if ($LASTEXITCODE -ne 0) { Pop-Location; Abort "npm install morgan failed" }

# Quick syntax check (does NOT start server)
Write-Host "Syntax check: node --check index.js" -ForegroundColor Yellow
node --check index.js
if ($LASTEXITCODE -ne 0) { Pop-Location; Abort "Syntax check failed. Open backend/index.js and fix the syntax error above." }
Pop-Location

# Git branch + commit + push
$branch = "fix/backend-morgan-" + (Get-Date -Format "yyyyMMdd-HHmmss")
Write-Host "Creating branch: $branch" -ForegroundColor Yellow
git switch -c $branch | Out-Null
if ($LASTEXITCODE -ne 0) { Abort "Could not create branch. (Are you in a detached state?)" }

git add backend/package.json backend/package-lock.json backend/index.js | Out-Null

$staged = (git diff --cached --name-only)
if (-not $staged) { Abort "Nothing staged. Did npm modify backend/package.json?" }

git commit -m "Backend: add missing morgan dependency (fix Render start)" | Out-Host
if ($LASTEXITCODE -ne 0) { Abort "Commit failed" }

Write-Host "Pushing branch..." -ForegroundColor Yellow
git push -u origin $branch | Out-Host
if ($LASTEXITCODE -ne 0) { Abort "Push failed" }

Write-Host ""
Write-Host "✅ DONE:" -ForegroundColor Green
Write-Host "1) Open GitHub -> Pull Requests -> New PR for '$branch' -> Merge to main" -ForegroundColor Cyan
Write-Host "2) Render -> your backend service -> Deploy latest (auto deploy should run after merge)" -ForegroundColor Cyan
Write-Host "3) Test: https://confusion-ai.onrender.com/health" -ForegroundColor Cyan
Write-Host "4) Then try Analyze again on Vercel" -ForegroundColor Cyan
