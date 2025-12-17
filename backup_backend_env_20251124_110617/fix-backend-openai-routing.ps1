param(
    [string]$BackendRoot = "."
)

$BackendRoot = (Resolve-Path $BackendRoot).Path
Write-Host "=== Confusion-AI backend OpenAI routing fix ===" -ForegroundColor Cyan
Write-Host "Backend root: $BackendRoot" -ForegroundColor Cyan

# 1) Backup backend
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $BackendRoot -Parent
$backupDir = Join-Path $backupParent ("backup_backend_openai_routing_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
Copy-Item -Path $BackendRoot -Destination $backupDir -Recurse -Force
Write-Host "Backup complete." -ForegroundColor Green

$indexPath = Join-Path $BackendRoot "index.js"
$routePath
