param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend",
  [string]$Branch = "main"
)

Write-Host "=== Fix Vercel Deploy: remove node_modules from Git + ignore ===" -ForegroundColor Cyan

# Resolve repo root
try { $root = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
Set-Location $root
Write-Host "Repo root: $root" -ForegroundColor Yellow

# Ensure we're on main
$cur = (git rev-parse --abbrev-ref HEAD).Trim()
if ($cur -ne $Branch) {
  Write-Host "Switching branch $cur -> $Branch" -ForegroundColor Yellow
  git checkout $Branch 2>$null
  if ($LASTEXITCODE -ne 0) { git checkout -b $Branch }
}

$frontendPath = Join-Path $root $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend folder not found: $frontendPath"; exit 1 }

# Backup .gitignore
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$gitignore = Join-Path $root ".gitignore"
if (Test-Path $gitignore) {
  Copy-Item $gitignore "$gitignore.bak-$timestamp" -Force
  Write-Host "Backed up .gitignore -> .gitignore.bak-$timestamp" -ForegroundColor DarkGray
}

# Write/merge .gitignore entries (repo root)
$linesToEnsure = @(
  "# --- Confusion-AI ignores ---",
  ".env",
  ".env.*",
  "*.log",
  ".DS_Store",
  ".vercel/",
  "node_modules/",
  "**/node_modules/",
  "dist/",
  "**/dist/",
  "coverage/",
  "android/",
  "ios/",
  "*.keystore",
  "*.jks"
)

$existing = @()
if (Test-Path $gitignore) { $existing = Get-Content $gitignore }
foreach ($l in $linesToEnsure) {
  if (-not ($existing -contains $l)) { $existing += $l }
}
$existing | Set-Content -Path $gitignore -Encoding UTF8
Write-Host "Updated .gitignore" -ForegroundColor Green

# Remove tracked node_modules/dist from git index (critical)
$targets = @(
  (Join-Path $FrontendDir "node_modules"),
  (Join-Path $FrontendDir "dist")
)

foreach ($t in $targets) {
  # If tracked, remove from index
  $tracked = git ls-files $t 2>$null
  if ($tracked) {
    Write-Host "Removing tracked from git index: $t" -ForegroundColor Yellow
    git rm -r --cached $t | Out-Null
  } else {
    Write-Host "Not tracked (ok): $t" -ForegroundColor DarkGray
  }
}

# Also delete local folders to prevent re-adding by accident (you can reinstall anytime)
$localNodeModules = Join-Path $frontendPath "node_modules"
$localDist = Join-Path $frontendPath "dist"
if (Test-Path $localNodeModules) {
  Write-Host "Deleting local frontend/node_modules (will be reinstalled)..." -ForegroundColor Yellow
  Remove-Item $localNodeModules -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $localDist) {
  Write-Host "Deleting local frontend/dist..." -ForegroundColor Yellow
  Remove-Item $localDist -Recurse -Force -ErrorAction SilentlyContinue
}

# Reinstall and build locally (sanity)
Push-Location $frontendPath
Write-Host "npm install --include=dev" -ForegroundColor Yellow
npm install --include=dev
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

Write-Host "npm run build" -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location
if ($exit -ne 0) { Write-Error "Local build failed. Paste the FIRST 30 lines of the error."; exit 1 }

Write-Host "✅ Local build OK." -ForegroundColor Green

# Commit + push
$changes = git status --porcelain
if (-not $changes) {
  Write-Host "No changes to commit." -ForegroundColor DarkGray
  exit 0
}

git add .gitignore
git add -A
git commit -m "Remove node_modules/dist from repo to fix Vercel builds"
git push origin $Branch

Write-Host "=== Done. Now: Vercel Clear Cache + Redeploy ===" -ForegroundColor Cyan
