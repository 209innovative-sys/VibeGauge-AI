param(
    [string]$RepoRoot = ".",
    [string]$FrontendDir = "frontend"
)

Write-Host "=== Confusion-AI: Fix frontend build script for Vercel ===" -ForegroundColor Cyan

# Resolve repo root
try {
    $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
} catch {
    Write-Error "Repo root not found: $RepoRoot"
    exit 1
}

Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
$pkgPath      = Join-Path $frontendPath "package.json"

if (-not (Test-Path $frontendPath)) {
    Write-Error "Frontend directory not found: $frontendPath"
    exit 1
}
if (-not (Test-Path $pkgPath)) {
    Write-Error "package.json not found at: $pkgPath"
    exit 1
}

# Backup package.json
$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$pkgPath.bak-$timestamp"
Copy-Item -Path $pkgPath -Destination $backupPath -Force
Write-Host "Backed up package.json to: $backupPath" -ForegroundColor Green

# Load & patch JSON
$jsonText = Get-Content -Path $pkgPath -Raw
$pkgJson  = $jsonText | ConvertFrom-Json

if (-not $pkgJson.scripts) {
    $pkgJson | Add-Member -MemberType NoteProperty -Name scripts -Value (@{}) -Force
}

# Force Vite scripts (Linux-friendly)
$pkgJson.scripts.dev     = "vite"
$pkgJson.scripts.build   = "vite build"
$pkgJson.scripts.preview = "vite preview"

# Write back
$pkgJson | ConvertTo-Json -Depth 10 | Set-Content -Path $pkgPath -Encoding UTF8
Write-Host "Updated scripts in package.json to use vite/vite build/vite preview." -ForegroundColor Green

Write-Host "=== Done. Now run 'npm run build' inside frontend to confirm. ===" -ForegroundColor Cyan
