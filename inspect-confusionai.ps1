param(
    [string]$RepoRoot = ".",
    [switch]$OpenLog
)

Write-Host "=== Confusion-AI Repo Inspection ===" -ForegroundColor Cyan

# Resolve and verify repo root
try {
    $resolvedRoot = Resolve-Path -Path $RepoRoot -ErrorAction Stop
} catch {
    Write-Error "Repo root path not found: $RepoRoot"
    exit 1
}

Set-Location $resolvedRoot
Write-Host "Repo root: $(Get-Location)" -ForegroundColor Yellow

# Prepare log directory
$logDir = Join-Path (Get-Location) "_confusionai_logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "repo-inspect-$timestamp.txt"

Write-Host "Logging details to: $logFile" -ForegroundColor Yellow

"=== Confusion-AI Repo Inspection ===" | Out-File -FilePath $logFile -Encoding utf8
"Timestamp: $(Get-Date -Format o)" | Out-File -FilePath $logFile -Encoding utf8 -Append
"Repo root: $(Get-Location)" | Out-File -FilePath $logFile -Encoding utf8 -Append
"" | Out-File -FilePath $logFile -Encoding utf8 -Append

# 1) High-level tree (depth-limited) using 'tree' if available
"--- Directory Tree (Top Levels) ---" | Out-File -FilePath $logFile -Encoding utf8 -Append
try {
    # /F = list files, /A = ASCII
    & tree . /F /A | Out-File -FilePath $logFile -Encoding utf8 -Append
} catch {
    "tree command not available; using Get-ChildItem fallback." | Out-File -FilePath $logFile -Encoding utf8 -Append
    Get-ChildItem -Recurse | Select-Object FullName | Out-File -FilePath $logFile -Encoding utf8 -Append
}
"" | Out-File -FilePath $logFile -Encoding utf8 -Append

# 2) Detect package.json files and guess frontend/backend
"--- Detected package.json Files ---" | Out-File -FilePath $logFile -Encoding utf8 -Append

$packageFiles = Get-ChildItem -Path . -Filter "package.json" -Recurse -ErrorAction SilentlyContinue

if (-not $packageFiles) {
    "No package.json files found." | Out-File -FilePath $logFile -Encoding utf8 -Append
} else {
    $frontendCandidates = @()
    $backendCandidates  = @()

    foreach ($pkg in $packageFiles) {
        "Found: $($pkg.FullName)" | Out-File -FilePath $logFile -Encoding utf8 -Append
        try {
            $jsonText = Get-Content -Path $pkg.FullName -Raw -ErrorAction Stop
            $pkgJson = $jsonText | ConvertFrom-Json

            $deps = @()
            if ($pkgJson.dependencies) { $deps += $pkgJson.dependencies.PSObject.Properties.Name }
            if ($pkgJson.devDependencies) { $deps += $pkgJson.devDependencies.PSObject.Properties.Name }

            $isFrontend = $false
            $isBackend  = $false

            if ($deps -contains "vite" -or $deps -contains "react" -or $deps -contains "react-dom") {
                $isFrontend = $true
            }
            if ($deps -contains "express" -or $deps -contains "cors" || $deps -contains "body-parser") {
                $isBackend = $true
            }

            if ($isFrontend) {
                $frontendCandidates += $pkg.DirectoryName
            }
            if ($isBackend) {
                $backendCandidates += $pkg.DirectoryName
            }
        } catch {
            "  (Could not parse JSON in $($pkg.FullName))" | Out-File -FilePath $logFile -Encoding utf8 -Append
        }
    }

    "" | Out-File -FilePath $logFile -Encoding utf8 -Append
    "--- Inferred Frontend Candidates ---" | Out-File -FilePath $logFile -Encoding utf8 -Append
    if ($frontendCandidates.Count -eq 0) {
        "None detected via deps." | Out-File -FilePath $logFile -Encoding utf8 -Append
    } else {
        $frontendCandidates | Sort-Object -Unique | ForEach-Object {
            $_ | Out-File -FilePath $logFile -Encoding utf8 -Append
        }
    }

    "" | Out-File -FilePath $logFile -Encoding utf8 -Append
    "--- Inferred Backend Candidates ---" | Out-File -FilePath $logFile -Encoding utf8 -Append
    if ($backendCandidates.Count -eq 0) {
        "None detected via deps." | Out-File -FilePath $logFile -Encoding utf8 -Append
    } else {
        $backendCandidates | Sort-Object -Unique | ForEach-Object {
            $_ | Out-File -FilePath $logFile -Encoding utf8 -Append
        }
    }
}
"" | Out-File -FilePath $logFile -Encoding utf8 -Append

# 3) Detect .env files
"--- Detected .env* Files ---" | Out-File -FilePath $logFile -Encoding utf8 -Append
$envFiles = Get-ChildItem -Path . -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like ".env*" }

if (-not $envFiles) {
    "No .env* files found." | Out-File -FilePath $logFile -Encoding utf8 -Append
} else {
    foreach ($e in $envFiles) {
        $relPath = $e.FullName.Replace((Get-Location).Path, ".")
        $relPath | Out-File -FilePath $logFile -Encoding utf8 -Append
    }
}
"" | Out-File -FilePath $logFile -Encoding utf8 -Append

# 4) Console summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan

if ($packageFiles) {
    $frontendCandidates = $frontendCandidates | Sort-Object -Unique
    $backendCandidates  = $backendCandidates  | Sort-Object -Unique

    Write-Host "Frontend candidates:" -ForegroundColor Green
    if ($frontendCandidates.Count -eq 0) {
        Write-Host "  (none detected)" -ForegroundColor DarkGray
    } else {
        $frontendCandidates | ForEach-Object { Write-Host "  $_" }
    }

    Write-Host "`nBackend candidates:" -ForegroundColor Green
    if ($backendCandidates.Count -eq 0) {
        Write-Host "  (none detected)" -ForegroundColor DarkGray
    } else {
        $backendCandidates | ForEach-Object { Write-Host "  $_" }
    }
} else {
    Write-Host "No package.json files detected." -ForegroundColor Red
}

Write-Host "`n.env files found:" -ForegroundColor Green
if (-not $envFiles) {
    Write-Host "  (none)" -ForegroundColor DarkGray
} else {
    foreach ($e in $envFiles) {
        $relPath = $e.FullName.Replace((Get-Location).Path, ".")
        Write-Host "  $relPath"
    }
}

Write-Host "`nDetailed log: $logFile" -ForegroundColor Yellow

if ($OpenLog) {
    # Try to open the log in default editor
    try {
        Invoke-Item $logFile
    } catch {
        Write-Host "Could not open log automatically." -ForegroundColor DarkGray
    }
}

Write-Host "`n=== Inspection complete. ===" -ForegroundColor Cyan
