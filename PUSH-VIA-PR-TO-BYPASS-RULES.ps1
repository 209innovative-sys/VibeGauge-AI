param(
  [string]$RepoRoot = ".",
  [string]$BaseBranch = "main"
)

Write-Host "=== Confusion-AI: Push via PR (bypass main ruleset) ===" -ForegroundColor Cyan

try { $root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found"; exit 1 }
Set-Location $root
Write-Host "Repo root: $root" -ForegroundColor Yellow

# Confirm origin
Write-Host "`nOrigin:" -ForegroundColor Cyan
git remote -v

# Create a new branch name
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$branch = "confusionai-deploy-fix-$ts"

# Ensure we are on main (or base)
$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne $BaseBranch) {
  Write-Host "Switching to $BaseBranch..." -ForegroundColor Yellow
  git checkout $BaseBranch 2>$null
}

# Make sure we include any local commits already made
Write-Host "Creating branch: $branch" -ForegroundColor Yellow
git checkout -b $branch

# Quick sanity checks: tracked forbidden stuff
Write-Host "`nChecking for tracked forbidden folders/files..." -ForegroundColor Cyan
$trackedBad = @(
  "frontend/node_modules",
  "frontend/dist",
  "node_modules",
  "dist",
  "android",
  "ios",
  ".env",
  "backend/.env",
  "frontend/.env"
)

foreach ($p in $trackedBad) {
  $t = git ls-files $p 2>$null
  if ($t) { Write-Host "⚠️ TRACKED in git: $p" -ForegroundColor Yellow }
}

# Show largest tracked files (helps detect rules like file-size)
Write-Host "`nTop tracked file sizes (largest 15):" -ForegroundColor Cyan
$files = git ls-files
$items = @()
foreach ($f in $files) {
  $full = Join-Path $root $f
  if (Test-Path $full) {
    $len = (Get-Item $full).Length
    $items += [pscustomobject]@{ File=$f; MB=[math]::Round($len/1MB,2) }
  }
}
$items | Sort-Object MB -Descending | Select-Object -First 15 | Format-Table -AutoSize

# Try pushing the branch (this is usually allowed even when main is protected)
Write-Host "`nPushing branch to GitHub: $branch" -ForegroundColor Yellow
git push -u origin $branch
if ($LASTEXITCODE -ne 0) {
  Write-Error "Branch push failed too. This is likely secrets/file-policy blocking. Do NOT paste secrets. Paste the last 25 lines of the git push output."
  exit 1
}

Write-Host "`n✅ Branch pushed successfully." -ForegroundColor Green
Write-Host "NEXT: Open GitHub -> Pull Requests -> New PR" -ForegroundColor Cyan
Write-Host "Base: $BaseBranch   Compare: $branch" -ForegroundColor Cyan
Write-Host "Merge the PR. After merge, Vercel will deploy from main." -ForegroundColor Cyan
