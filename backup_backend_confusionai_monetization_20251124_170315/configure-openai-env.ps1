param(
    [string]$BackendRoot = "."
)

$BackendRoot = (Resolve-Path $BackendRoot).Path
Write-Host "=== Confusion-AI backend OpenAI env setup ===" -ForegroundColor Cyan
Write-Host "Backend root: $BackendRoot" -ForegroundColor Cyan

# 1) Backup backend
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $BackendRoot -Parent
$backupDir = Join-Path $backupParent ("backup_backend_env_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
Copy-Item -Path $BackendRoot -Destination $backupDir -Recurse -Force
Write-Host "Backup complete." -ForegroundColor Green

# 2) Ensure dotenv is installed
Write-Host "Ensuring 'dotenv' package is installed..." -ForegroundColor Yellow
Push-Location $BackendRoot
try {
    npm install dotenv | Out-Null
    Write-Host "dotenv installed (or already present)." -ForegroundColor Green
} catch {
    Write-Host "npm install dotenv failed. Check npm logs if something is broken." -ForegroundColor Red
}
Pop-Location

# 3) Ensure index.js calls require('dotenv').config();
$indexPath = Join-Path $BackendRoot "index.js"
if (-not (Test-Path $indexPath)) {
    Write-Host "ERROR: index.js not found at $indexPath" -ForegroundColor Red
    Write-Host "Cannot inject dotenv automatically." -ForegroundColor Red
} else {
    Write-Host "Checking index.js for dotenv config..." -ForegroundColor Yellow
    $idx = Get-Content -Path $indexPath -Raw

    if ($idx -notmatch "dotenv\.config\(\)") {
        Write-Host "Adding require('dotenv').config(); to index.js..." -ForegroundColor Yellow

        $lines = $idx -split "`r?`n"
        $insertLine = "require(""dotenv"").config();"

        $useStrictIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "'use strict'" -or $lines[$i] -match '"use strict"') {
                $useStrictIndex = $i
                break
            }
        }

        if ($useStrictIndex -ge 0) {
            $before = $lines[0..$useStrictIndex]
            $after = @()
            if ($useStrictIndex -lt $lines.Count - 1) {
                $after = $lines[($useStrictIndex + 1)..($lines.Count - 1)]
            }
            $lines = $before + $insertLine + $after
        } else {
            $lines = ,$insertLine + $lines
        }

        $newIdx = [string]::Join("`r`n", $lines)
        Set-Content -Path $indexPath -Value $newIdx -Encoding UTF8
        Write-Host "index.js updated to load .env via dotenv." -ForegroundColor Green
    } else {
        Write-Host "index.js already uses dotenv.config()." -ForegroundColor DarkGray
    }
}

# 4) Prompt for OpenAI API key and write backend .env
$envPath = Join-Path $BackendRoot ".env"
Write-Host ""
Write-Host "IMPORTANT: You are about to enter your OpenAI API key locally." -ForegroundColor Yellow
Write-Host "DO NOT paste this key into ChatGPT or share it with anyone." -ForegroundColor Yellow
Write-Host ""

$apiKey = Read-Host "Paste your OPENAI_API_KEY (sk-...)"

if (-not $apiKey -or $apiKey.Trim().Length -eq 0) {
    Write-Host "No key entered. Aborting .env update." -ForegroundColor Red
    exit 1
}

Write-Host "Writing OPENAI_API_KEY to backend .env..." -ForegroundColor Yellow

if (Test-Path $envPath) {
    $envLines = Get-Content -Path $envPath
    # Remove any existing OPENAI_API_KEY lines
    $filtered = $envLines | Where-Object {$_ -notmatch "^OPENAI_API_KEY="}
    $filtered | Set-Content -Path $envPath -Encoding UTF8
    Add-Content -Path $envPath -Value "OPENAI_API_KEY=$apiKey"
} else {
    "OPENAI_API_KEY=$apiKey" | Set-Content -Path $envPath -Encoding UTF8
}

Write-Host "Backend .env updated with OPENAI_API_KEY." -ForegroundColor Green
Write-Host ""
Write-Host "=== Done. Restart the backend with: npm start ===" -ForegroundColor Cyan
Write-Host "If your trial is out, the next error will be about quota/billing instead of 'Missing credentials'." -ForegroundColor Cyan
