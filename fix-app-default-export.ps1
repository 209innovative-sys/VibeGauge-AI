param(
    # Frontend root; change if your frontend is in a subfolder
    [string]$FrontendRoot = "."
)

Write-Host "=== Confusion-AI App.tsx default export fixer ===" -ForegroundColor Cyan

$FrontendRoot = (Resolve-Path $FrontendRoot).Path
Write-Host "Frontend root: $FrontendRoot" -ForegroundColor Cyan

# 1) Find App.tsx / App.jsx
Write-Host "Searching for App.tsx / App.jsx..." -ForegroundColor Yellow
$appFile = Get-ChildItem -Path $FrontendRoot -Recurse -File -Include "App.tsx","App.jsx" | Select-Object -First 1

if (-not $appFile) {
    Write-Host "ERROR: Could not find App.tsx or App.jsx under $FrontendRoot" -ForegroundColor Red
    exit 1
}

$appPath = $appFile.FullName
Write-Host "Using app file: $appPath" -ForegroundColor Green

# 2) Backup
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path (Split-Path $FrontendRoot -Parent) ("backup_confusionai_appfix_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
Copy-Item -Path $FrontendRoot -Destination $backupDir -Recurse -Force
Write-Host "Backup complete." -ForegroundColor Green

# 3) Fix default export
$appContent = Get-Content -Path $appPath -Raw

if ($appContent -match "export\s+default\s+") {
    Write-Host "App file already has a default export. Nothing to change." -ForegroundColor DarkGray
    exit 0
}

Write-Host "No default export found in App file. Attempting to add one..." -ForegroundColor Yellow

# Try to detect the main component name
$componentName = $null

# Common patterns
if ($appContent -match "function\s+App\s*\(") {
    $componentName = "App"
} elseif ($appContent -match "const\s+App\s*[:=]") {
    $componentName = "App"
} elseif ($appContent -match "export\s+const\s+App\s*[:=]") {
    # Already exported as named, just need default
    $componentName = "App"
} else {
    # Fallback: guess App
    $componentName = "App"
    Write-Host "WARNING: Could not detect a specific component name, using 'App' as default." -ForegroundColor Yellow
}

# Append default export at the end
$appendText = "`r`n`r`nexport default $componentName;`r`n"
$appContent = $appContent + $appendText

Set-Content -Path $appPath -Value $appContent -Encoding UTF8

Write-Host "Added 'export default $componentName;' to App file." -ForegroundColor Green
Write-Host "=== Done. Try restarting your Vite dev server (npm run dev) and refresh the browser. ===" -ForegroundColor Cyan
Write-Host "Backup of the previous frontend is at: $backupDir" -ForegroundColor Cyan
