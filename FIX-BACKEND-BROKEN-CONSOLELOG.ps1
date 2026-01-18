param(
  [string]$RepoRoot=".",
  [string]$BackendDir="backend"
)

Write-Host "=== Fix backend: patch any broken console.log lines ===" -ForegroundColor Cyan

$root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
Set-Location $root

$indexJs = Join-Path (Join-Path $root $BackendDir) "index.js"
if (-not (Test-Path $indexJs)) { Write-Error "Missing: $indexJs"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $indexJs "$indexJs.bak-$ts" -Force
Write-Host "Backup: backend/index.js.bak-$ts" -ForegroundColor DarkGray

$raw = Get-Content $indexJs -Raw
$orig = $raw

# Patch the exact broken line (and close variants)
$raw = [regex]::Replace(
  $raw,
  '(?m)^\s*console\.log\(\s*Confusion-?AI\s+backend\s+listening\s+on\s+port\s*\)\s*;\s*$',
  'console.log(`Confusion-AI backend listening on port ${process.env.PORT || 4000}`);'
)

# Patch if it exists with missing close paren content like: console.log(Confusion-AI backend listening on port );
$raw = [regex]::Replace(
  $raw,
  '(?m)^\s*console\.log\(\s*Confusion-?AI\s+backend\s+listening\s+on\s+port\s*;\s*$',
  'console.log(`Confusion-AI backend listening on port ${process.env.PORT || 4000}`);'
)

# Also patch any other "console.log(Confusion-AI ..." with no quotes/backticks (safe, minimal)
$raw = [regex]::Replace(
  $raw,
  '(?m)^\s*console\.log\(\s*(Confusion-?AI[^`"''\)]*)\)\s*;\s*$',
  'console.log(`$1`);'
)

# Write UTF-8 no BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexJs, $raw, $utf8NoBom)

if ($raw -eq $orig) {
  Write-Host "WARNING: No matching broken console.log found. Still running syntax check..." -ForegroundColor Yellow
} else {
  Write-Host "✅ Patched broken console.log line(s)" -ForegroundColor Green
}

# Syntax check compile only
node -e "new Function(require('fs').readFileSync('backend/index.js','utf8')); console.log('syntax ok')" | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Error "Syntax check still failing. Open backend/index.js and search for 'console.log('Confusion'"; exit 1 }

# Commit + push to branch
$branch = "fix/backend-syntax-" + (Get-Date -Format "yyyyMMdd-HHmmss")
git switch -c $branch | Out-Null
git add backend/index.js | Out-Null
git commit -m "Fix backend syntax: quote broken console.log" | Out-Host
git push -u origin (git rev-parse --abbrev-ref HEAD) | Out-Host

Write-Host "✅ Done. Make a PR -> merge to main -> redeploy Render." -ForegroundColor Cyan
