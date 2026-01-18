param(
  [string]$RepoRoot=".",
  [string]$BackendDir="backend"
)

Write-Host "=== Fix Render crash: dataUrl line ===" -ForegroundColor Cyan

$root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
Set-Location $root

$indexJs = Join-Path (Join-Path $root $BackendDir) "index.js"
if (-not (Test-Path $indexJs)) { Write-Error "Missing: $indexJs"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $indexJs "$indexJs.bak-$ts" -Force
Write-Host "Backup: backend/index.js.bak-$ts" -ForegroundColor DarkGray

$raw  = Get-Content $indexJs -Raw
$orig = $raw

# Replace any corrupted dataUrl line like: const dataUrl = data:;base64,;
$raw = [regex]::Replace(
  $raw,
  '(?m)^\s*const\s+dataUrl\s*=\s*data:.*$',
  '  const dataUrl = `data:${mimeType};base64,${imageBuffer.toString("base64")}`;'
)

# If it didn't match, also catch a partially broken variant
$raw = [regex]::Replace(
  $raw,
  '(?m)^\s*const\s+dataUrl\s*=.*base64.*$',
  '  const dataUrl = `data:${mimeType};base64,${imageBuffer.toString("base64")}`;'
)

if ($raw -eq $orig) {
  Write-Host "WARNING: Could not find a dataUrl line to patch. Open backend/index.js and search for 'dataUrl'." -ForegroundColor Yellow
  exit 1
}

# Write UTF-8 no BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexJs, $raw, $utf8NoBom)
Write-Host "✅ Patched backend/index.js dataUrl line" -ForegroundColor Green

# Quick syntax check
node -e "new Function(require('fs').readFileSync('backend/index.js','utf8')); console.log('syntax ok')" | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Error "Syntax check failed"; exit 1 }

# Commit + push on a new branch
$branch = "fix/render-dataurl-" + (Get-Date -Format "yyyyMMdd-HHmmss")
git switch -c $branch | Out-Null
git add backend/index.js | Out-Null
git commit -m "Fix Render crash: repair dataUrl template string" | Out-Host
git push -u origin (git rev-parse --abbrev-ref HEAD) | Out-Host

Write-Host "✅ Done. Open GitHub PR for this branch and merge to main, then redeploy on Render." -ForegroundColor Cyan
