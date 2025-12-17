param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend"
)

Write-Host "=== FIX: Remove UTF-8 BOM from frontend JSON files ===" -ForegroundColor Cyan

function Strip-Utf8Bom([string]$path, [string]$backupDir) {
  if (-not (Test-Path $path)) { return $false }
  $bytes = [System.IO.File]::ReadAllBytes($path)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $leaf = Split-Path $path -Leaf
    Copy-Item $path (Join-Path $backupDir "$leaf.bak") -Force
    $newBytes = $bytes[3..($bytes.Length-1)]
    [System.IO.File]::WriteAllBytes($path, $newBytes)
    Write-Host "Removed BOM: $path" -ForegroundColor Green
    return $true
  }
  Write-Host "No BOM: $path" -ForegroundColor DarkGray
  return $false
}

try { $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found: $RepoRoot"; exit 1 }
Set-Location $rootPath

$frontendPath = Join-Path $rootPath $FrontendDir
if (-not (Test-Path $frontendPath)) { Write-Error "Frontend directory not found: $frontendPath"; exit 1 }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_frontend_json_bom_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null
Write-Host "Backup dir: $backupDir" -ForegroundColor Yellow

# Strip BOM from ALL json files at frontend root (this fixes package.json most often)
Get-ChildItem -Path $frontendPath -File -Filter "*.json" -ErrorAction SilentlyContinue |
  ForEach-Object { Strip-Utf8Bom $_.FullName $backupDir | Out-Null }

# Also strip BOM from package-lock (sometimes huge but safe)
$lock = Join-Path $frontendPath "package-lock.json"
Strip-Utf8Bom $lock $backupDir | Out-Null

# Reinstall with dev deps + build
Push-Location $frontendPath
Write-Host "npm install --include=dev" -ForegroundColor Yellow
npm install --include=dev
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "npm install failed"; exit 1 }

Write-Host "npm run build" -ForegroundColor Yellow
npm run build
$exit = $LASTEXITCODE
Pop-Location

if ($exit -ne 0) {
  Write-Error "Build still failed. Paste the FIRST 30 lines of the error."
  exit 1
}

Write-Host "✅ Local build succeeded." -ForegroundColor Cyan
Write-Host "Next: git commit + push, then redeploy on Vercel." -ForegroundColor Cyan
