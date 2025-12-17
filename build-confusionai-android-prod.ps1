param(
    [string]$RepoRoot = ".",
    [string]$FrontendDir = "frontend",

    # Confusion-AI backend on Render (prod)
    [string]$BackendProdUrl = "https://confusion-ai.onrender.com"
)

Write-Host "=== Confusion-AI: Android build using production backend URL ===" -ForegroundColor Cyan

# Resolve repo root
try {
    $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
} catch {
    Write-Error "Repo root not found: $RepoRoot"
    exit 1
}

Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath   = Join-Path $rootPath $FrontendDir
$capConfigPath  = Join-Path $frontendPath "capacitor.config.ts"
$androidDir     = Join-Path $frontendPath "android"
$envPath        = Join-Path $frontendPath ".env"
$androidEnvPath = Join-Path $frontendPath ".env.android"

if (-not (Test-Path $frontendPath)) {
    Write-Error "Frontend directory not found: $frontendPath"
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $rootPath ("backup_frontend_android_env_" + $timestamp)
New-Item -ItemType Directory -Path $backupDir -ErrorAction SilentlyContinue | Out-Null

# -------------------------------------------------------------------
# Ensure capacitor.config.ts exists
# -------------------------------------------------------------------
if (-not (Test-Path $capConfigPath)) {
    Write-Host "capacitor.config.ts not found. Creating a default one..." -ForegroundColor Yellow

    $capContent = @"
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.innovativesolutions.confusionai',
  appName: 'Confusion AI',
  webDir: 'dist',
  bundledWebRuntime: false,
};

export default config;
"@

    Set-Content -Path $capConfigPath -Value $capContent -Encoding UTF8
    Write-Host "capacitor.config.ts written to: $capConfigPath" -ForegroundColor Green
}

# -------------------------------------------------------------------
# Install Capacitor packages (idempotent)
# -------------------------------------------------------------------
Write-Host "Installing Capacitor packages in frontend (idempotent)..." -ForegroundColor Yellow
Push-Location $frontendPath
npm install @capacitor/core @capacitor/cli @capacitor/android --save-dev
Pop-Location
Write-Host "Capacitor packages installed (or already present)." -ForegroundColor Green

# -------------------------------------------------------------------
# Backup current .env if present
# -------------------------------------------------------------------
$devEnvBackupPath = $null
if (Test-Path $envPath) {
    $devEnvBackupPath = Join-Path $backupDir ".env.devbackup"
    Copy-Item -Path $envPath -Destination $devEnvBackupPath -Force
    Write-Host "Backed up existing .env to: $devEnvBackupPath" -ForegroundColor Green
}

# Write .env.android (for reference)
$androidEnvContent = @"
# Android/production build env for Confusion-AI
# IMPORTANT: This value is baked into the Android app at build time.
VITE_API_BASE_URL=$BackendProdUrl
"@
Set-Content -Path $androidEnvPath -Value $androidEnvContent -Encoding UTF8
Write-Host ".env.android written at: $androidEnvPath" -ForegroundColor Green

# Swap in a temporary .env for the Android build
Set-Content -Path $envPath -Value "VITE_API_BASE_URL=$BackendProdUrl" -Encoding UTF8
Write-Host "Temporary .env set for Android build with VITE_API_BASE_URL=$BackendProdUrl" -ForegroundColor Yellow

# -------------------------------------------------------------------
# Build + add/sync Android
# -------------------------------------------------------------------
Write-Host "Running npm run build in frontend..." -ForegroundColor Yellow
Push-Location $frontendPath
npm run build
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "npm run build failed. Aborting."
    exit 1
}

if (-not (Test-Path $androidDir)) {
    Write-Host "Android platform not found. Adding Android platform (npx cap add android)..." -ForegroundColor Yellow
    npx cap add android
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Error "npx cap add android failed. Aborting."
        exit 1
    }
    Write-Host "Android platform added." -ForegroundColor Green
} else {
    Write-Host "Android platform already exists. Syncing (npx cap sync android)..." -ForegroundColor Yellow
    npx cap sync android
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Error "npx cap sync android failed. Aborting."
        exit 1
    }
    Write-Host "Android project synced." -ForegroundColor Green
}
Pop-Location

# -------------------------------------------------------------------
# Restore previous .env (for local dev)
# -------------------------------------------------------------------
if ($devEnvBackupPath -and (Test-Path $devEnvBackupPath)) {
    Move-Item -Path $devEnvBackupPath -Destination $envPath -Force
    Write-Host "Restored original .env after build." -ForegroundColor Green
} else {
    if (Test-Path $envPath) {
        # Leave this one if you like, or remove. We'll remove to keep dev clean.
        Remove-Item $envPath -Force
        Write-Host "Removed temporary .env (no original env to restore)." -ForegroundColor DarkYellow
    }
}

Write-Host "=== Done. Android project is ready under frontend/android. ===" -ForegroundColor Cyan
Write-Host "Now open that folder in Android Studio and generate your signed AAB." -ForegroundColor Cyan
