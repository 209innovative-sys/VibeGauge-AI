param(
    [string]$RepoRoot = ".",
    [string]$FrontendDir = "frontend",
    [string]$AppId = "com.innovativesolutions.confusionai",
    [string]$AppName = "Confusion AI"
)

Write-Host "=== Confusion-AI: Create Android Project (Capacitor) ===" -ForegroundColor Cyan

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
if (-not (Test-Path $frontendPath)) {
    Write-Error "Frontend directory not found: $frontendPath"
    exit 1
}

$capConfigPath = Join-Path $frontendPath "capacitor.config.ts"
$androidDir    = Join-Path $frontendPath "android"

# -------------------------------------------------------------------
# Backup existing capacitor.config.ts (if any)
# -------------------------------------------------------------------
$timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDirRoot = Join-Path $rootPath ("backup_capacitor_confusionai_" + $timestamp)
New-Item -ItemType Directory -Path $backupDirRoot -ErrorAction SilentlyContinue | Out-Null

if (Test-Path $capConfigPath) {
    Copy-Item -Path $capConfigPath -Destination (Join-Path $backupDirRoot "capacitor.config.ts") -Force
    Write-Host "Backed up capacitor.config.ts to: $backupDirRoot" -ForegroundColor Green
}

# -------------------------------------------------------------------
# Ensure capacitor.config.ts has our config
# -------------------------------------------------------------------
Write-Host "Writing capacitor.config.ts..." -ForegroundColor Yellow

$capContent = @"
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: '$AppId',
  appName: '$AppName',
  webDir: 'dist',
  bundledWebRuntime: false,
};

export default config;
"@

Set-Content -Path $capConfigPath -Value $capContent -Encoding UTF8
Write-Host "capacitor.config.ts written." -ForegroundColor Green

# -------------------------------------------------------------------
# Install Capacitor packages (idempotent)
# -------------------------------------------------------------------
Write-Host "Installing Capacitor packages in frontend..." -ForegroundColor Yellow
Push-Location $frontendPath
npm install @capacitor/core @capacitor/cli @capacitor/android --save-dev
Pop-Location
Write-Host "Capacitor packages installed (or already present)." -ForegroundColor Green

# -------------------------------------------------------------------
# Build web app (dist/)
# -------------------------------------------------------------------
Write-Host "Building frontend (npm run build)..." -ForegroundColor Yellow
Push-Location $frontendPath
npm run build
Pop-Location
Write-Host "Frontend build complete (dist/ ready)." -ForegroundColor Green

# -------------------------------------------------------------------
# Add or sync Android platform
# -------------------------------------------------------------------
if (-not (Test-Path $androidDir)) {
    Write-Host "No android folder found. Adding Android platform..." -ForegroundColor Yellow
    Push-Location $frontendPath
    npx cap add android
    Pop-Location
    Write-Host "Android platform added (android/ created)." -ForegroundColor Green
} else {
    Write-Host "android folder already exists. Running npx cap sync android..." -ForegroundColor Yellow
    Push-Location $frontendPath
    npx cap sync android
    Pop-Location
    Write-Host "Android project synced." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Done. Android project should now exist at: $androidDir ===" -ForegroundColor Cyan
