param(
  [string]$RepoRoot=".",
  [string]$BackendDir="backend"
)

Write-Host "=== Fix backend syntax: app.listen + console.log ===" -ForegroundColor Cyan

$root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
Set-Location $root

$indexJs = Join-Path (Join-Path $root $BackendDir) "index.js"
if (-not (Test-Path $indexJs)) { Write-Error "Missing: $indexJs"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $indexJs "$indexJs.bak-$ts" -Force
Write-Host "Backup: backend/index.js.bak-$ts" -ForegroundColor DarkGray

$raw = Get-Content $indexJs -Raw

# Decide which port variable exists (PORT vs port). If neither exists, we will define PORT.
$portVar = "PORT"
$needsPortConst = $true
if ($raw -match '(?m)\b(const|let|var)\s+PORT\b') { $portVar="PORT"; $needsPortConst=$false }
elseif ($raw -match '(?m)\b(const|let|var)\s+port\b') { $portVar="port"; $needsPortConst=$false }

# Remove the existing listen block at the end (or any later)
$opts = [System.Text.RegularExpressions.RegexOptions]::RightToLeft
$m = [regex]::Match($raw, "(?m)^\s*(app|server)\.listen\(", $opts)

if ($m.Success) {
  $raw = $raw.Substring(0, $m.Index).TrimEnd()
}

# Build a clean, correct listen block
$listen = ""
if ($needsPortConst) {
  $listen += "const PORT = process.env.PORT || 4000;`r`n"
  $portVar = "PORT"
}

$listen += @"
app.listen($portVar, () => {
  console.log(`Confusion-AI backend listening on port ${$portVar}`);
});
"@

$raw = $raw + "`r`n`r`n" + $listen + "`r`n"

# Write UTF-8 (no BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexJs, $raw, $utf8NoBom)
Write-Host "✅ Rewrote app.listen + console.log block" -ForegroundColor Green

# Syntax check (compile only)
node -e "new Function(require('fs').readFileSync('backend/index.js','utf8')); console.log('syntax ok')" | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Error "Syntax check failed again. Tell me the exact error line."; exit 1 }

# Commit + push
$branch = "fix/backend-listen-" + (Get-Date -Format "yyyyMMdd-HHmmss")
git switch -c $branch | Out-Null
git add backend/index.js | Out-Null
git commit -m "Fix backend startup: repair listen + console.log syntax" | Out-Host
git push -u origin (git rev-parse --abbrev-ref HEAD) | Out-Host

Write-Host "✅ Done. Open GitHub -> PR -> merge to main. Then Render -> Deploy latest commit." -ForegroundColor Cyan
