param(
    # Frontend root (React + Vite)
    [string]$FrontendRoot = ".",

    # Backend root (Node + Express)
    [string]$BackendRoot = ".\backend"
)

Write-Host "=== Confusion-AI Screenshot Wiring Script ===" -ForegroundColor Cyan

# Resolve roots
$FrontendRoot = (Resolve-Path $FrontendRoot).Path
Write-Host "Frontend root: $FrontendRoot" -ForegroundColor Cyan

if (Test-Path $BackendRoot) {
    $BackendRoot = (Resolve-Path $BackendRoot).Path
    Write-Host "Backend root:  $BackendRoot" -ForegroundColor Cyan
} else {
    Write-Host "Backend root '$BackendRoot' not found. Backend wiring will be skipped." -ForegroundColor Yellow
    $BackendRoot = $null
}

# 1) Backup
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $FrontendRoot -Parent
$backupDir = Join-Path $backupParent ("backup_confusionai_wire_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

# backup frontend
$frontendBackup = Join-Path $backupDir "frontend"
Copy-Item -Path $FrontendRoot -Destination $frontendBackup -Recurse -Force

# backup backend
if ($BackendRoot) {
    $backendBackup = Join-Path $backupDir "backend"
    Copy-Item -Path $BackendRoot -Destination $backendBackup -Recurse -Force
}

Write-Host "Backup complete." -ForegroundColor Green

# ============================================================
# 2) FRONTEND WIRING (App.tsx + ScreenshotUpload)
# ============================================================

$screenshotPath = Join-Path $FrontendRoot "src\components\ScreenshotUpload.tsx"
$appPath = Join-Path $FrontendRoot "src\App.tsx"

if (-not (Test-Path $screenshotPath)) {
    Write-Host "WARNING: src/components/ScreenshotUpload.tsx not found. Run the add-screenshot-upload script first." -ForegroundColor Red
} else {
    Write-Host "Found ScreenshotUpload component." -ForegroundColor Green
}

if (-not (Test-Path $appPath)) {
    Write-Host "ERROR: src/App.tsx not found at $appPath. Cannot wire frontend automatically." -ForegroundColor Red
} else {
    Write-Host "Wiring ScreenshotUpload into App.tsx..." -ForegroundColor Yellow

    $appContent = Get-Content -Path $appPath -Raw
    $frontendChanged = $false

    # 2a) Ensure import line
    if ($appContent -notmatch "ScreenshotUpload") {
        $importLine = 'import ScreenshotUpload from "./components/ScreenshotUpload";'
        Write-Host "  Adding import for ScreenshotUpload..." -ForegroundColor Yellow

        $lines = $appContent -split "`r?`n"
        $lastImportIndex = -1

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].TrimStart().StartsWith("import ")) {
                $lastImportIndex = $i
            }
        }

        if ($lastImportIndex -ge 0) {
            $before = $lines[0..$lastImportIndex]
            $after = @()
            if ($lastImportIndex -lt $lines.Count - 1) {
                $after = $lines[($lastImportIndex + 1)..($lines.Count - 1)]
            }
            $lines = $before + $importLine + $after
        } else {
            $lines = ,$importLine + $lines
        }

        $appContent = [string]::Join("`r`n", $lines)
        $frontendChanged = $true
    } else {
        Write-Host "  ScreenshotUpload import already present." -ForegroundColor DarkGray
    }

    # 2b) Inject <ScreenshotUpload /> into JSX
    if ($appContent -notmatch "<ScreenshotUpload") {
        Write-Host "  Injecting <ScreenshotUpload ... /> into JSX..." -ForegroundColor Yellow

        # Heuristic: try to detect an analysis result setter
        $setterName = $null
        if ($appContent -match "setAnalysisResult") {
            $setterName = "setAnalysisResult"
        } elseif ($appContent -match "setResult") {
            $setterName = "setResult"
        } elseif ($appContent -match "setMetrics") {
            $setterName = "setMetrics"
        } elseif ($appContent -match "setAnalysis") {
            $setterName = "setAnalysis"
        }

        if ($setterName) {
            Write-Host "    Detected analysis setter: $setterName" -ForegroundColor Green
            $snippet = @"
    <ScreenshotUpload
      onResult={(data) => {
        $setterName(data);
      }}
      onError={(message) => {
        console.error(message);
      }}
    />
"@
        } else {
            Write-Host "WARNING: Could not detect analysis setter (setAnalysisResult/setResult/etc.). Using console.log in onResult." -ForegroundColor Yellow
            $snippet = @"
    <ScreenshotUpload
      onResult={(data) => {
        console.log("Screenshot result", data);
        // TODO: wire this into your analysis state (setAnalysisResult / setResult / etc.)
      }}
      onError={(message) => {
        console.error(message);
      }}
    />
"@
        }

        # Try to insert before closing </main>, else before last </div>
        if ($appContent.Contains("</main>")) {
            $pos = $appContent.LastIndexOf("</main>")
            if ($pos -ge 0) {
                $before = $appContent.Substring(0, $pos)
                $after = $appContent.Substring($pos)
                $appContent = $before + "`r`n" + $snippet + "`r`n" + $after
                $frontendChanged = $true
                Write-Host "    Injected before </main>." -ForegroundColor Green
            }
        } elseif ($appContent.Contains("</div>")) {
            $pos = $appContent.LastIndexOf("</div>")
            if ($pos -ge 0) {
                $before = $appContent.Substring(0, $pos)
                $after = $appContent.Substring($pos)
                $appContent = $before + "`r`n" + $snippet + "`r`n" + $after
                $frontendChanged = $true
                Write-Host "    Injected before last </div>." -ForegroundColor Green
            }
        } else {
            Write-Host "WARNING: Could not find </main> or </div> in App.tsx to inject ScreenshotUpload. Please add it manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ScreenshotUpload JSX already present in App.tsx." -ForegroundColor DarkGray
    }

    if ($frontendChanged) {
        Set-Content -Path $appPath -Value $appContent -Encoding UTF8
        Write-Host "App.tsx updated with ScreenshotUpload wiring." -ForegroundColor Green
    } else {
        Write-Host "No changes made to App.tsx (already wired or could not safely modify)." -ForegroundColor DarkGray
    }
}

# ============================================================
# 3) FRONTEND ENV: VITE_API_BASE_URL
# ============================================================

$envPath = Join-Path $FrontendRoot ".env"

if (Test-Path $envPath) {
    Write-Host "Checking .env for VITE_API_BASE_URL..." -ForegroundColor Yellow
    $envContent = Get-Content -Path $envPath -Raw
    if ($envContent -notmatch "VITE_API_BASE_URL") {
        Write-Host "  Adding VITE_API_BASE_URL to existing .env" -ForegroundColor Yellow
        Add-Content -Path $envPath -Value "`r`n# Confusion-AI backend base URL`r`nVITE_API_BASE_URL=http://localhost:5000"
        Write-Host "  Set default to http://localhost:5000 (change if using Render)." -ForegroundColor Green
    } else {
        Write-Host "  VITE_API_BASE_URL already present in .env" -ForegroundColor DarkGray
    }
} else {
    Write-Host "Creating new .env with VITE_API_BASE_URL..." -ForegroundColor Yellow
    $envTemplate = @'
# Confusion-AI frontend environment
VITE_API_BASE_URL=http://localhost:5000
'@
    Set-Content -Path $envPath -Value $envTemplate -Encoding UTF8
    Write-Host "  .env created. Change URL if backend is deployed." -ForegroundColor Green
}

# ============================================================
# 4) BACKEND WIRING: registerAnalyzeImageRoute
# ============================================================

if ($BackendRoot) {
    $serverFilePath = $null
    $candidates = @("server.js", "index.js", "app.js", "main.js")

    foreach ($name in $candidates) {
        $candidatePath = Join-Path $BackendRoot $name
        if (Test-Path $candidatePath) {
            $serverFilePath = $candidatePath
            break
        }
    }

    if (-not $serverFilePath) {
        Write-Host "WARNING: Could not find server.js/index.js/app.js/main.js in backend root. Skipping backend wiring." -ForegroundColor Yellow
    } else {
        Write-Host "Wiring backend server file: $serverFilePath" -ForegroundColor Yellow

        $serverLines = Get-Content -Path $serverFilePath
        $backendChanged = $false

        $serverJoined = $serverLines -join "`n"

        # 4a) Ensure require for registerAnalyzeImageRoute
        if ($serverJoined -notmatch "registerAnalyzeImageRoute") {
            Write-Host "  Adding require('./analyzeImageRoute')..." -ForegroundColor Yellow
            $insertLine = 'const { registerAnalyzeImageRoute } = require("./analyzeImageRoute");'

            $useStrictIndex = -1
            for ($i = 0; $i -lt $serverLines.Count; $i++) {
                if ($serverLines[$i] -match "'use strict'") {
                    $useStrictIndex = $i
                    break
                }
            }

            if ($useStrictIndex -ge 0) {
                $before = $serverLines[0..$useStrictIndex]
                $after = @()
                if ($useStrictIndex -lt $serverLines.Count - 1) {
                    $after = $serverLines[($useStrictIndex + 1)..($serverLines.Count - 1)]
                }
                $serverLines = $before + $insertLine + $after
            } else {
                $serverLines = ,$insertLine + $serverLines
            }

            $backendChanged = $true
        } else {
            Write-Host "  analyzeImageRoute require already present." -ForegroundColor DarkGray
        }

        # refresh joined string after possible change
        $serverJoined = $serverLines -join "`n"

        # 4b) Ensure registerAnalyzeImageRoute(app, openai); call
        if ($serverJoined -notmatch "registerAnalyzeImageRoute\(app,\s*openai\)") {
            Write-Host "  Adding registerAnalyzeImageRoute(app, openai) call..." -ForegroundColor Yellow
            $callLine = "registerAnalyzeImageRoute(app, openai);"

            $indexOpenai = -1
            for ($i = 0; $i -lt $serverLines.Count; $i++) {
                if ($serverLines[$i] -match "new OpenAI" -or $serverLines[$i] -match "const openai") {
                    $indexOpenai = $i
                }
            }

            if ($indexOpenai -ge 0) {
                $before = $serverLines[0..$indexOpenai]
                $after = @()
                if ($indexOpenai -lt $serverLines.Count - 1) {
                    $after = $serverLines[($indexOpenai + 1)..($serverLines.Count - 1)]
                }
                $serverLines = $before + $callLine + $after
                $backendChanged = $true
                Write-Host "    Inserted after OpenAI initialization." -ForegroundColor Green
            } else {
                # fallback: before app.listen if possible
                $indexListen = -1
                for ($i = 0; $i -lt $serverLines.Count; $i++) {
                    if ($serverLines[$i] -match "app\.listen") {
                        $indexListen = $i
                        break
                    }
                }

                if ($indexListen -ge 0) {
                    if ($indexListen -gt 0) {
                        $before = $serverLines[0..($indexListen - 1)]
                    } else {
                        $before = @()
                    }
                    $after = $serverLines[$indexListen..($serverLines.Count - 1)]
                    $serverLines = $before + $callLine + $after
                    $backendChanged = $true
                    Write-Host "    Inserted before app.listen(...)." -ForegroundColor Green
                } else {
                    # last resort: append to file
                    $serverLines += $callLine
                    $backendChanged = $true
                    Write-Host "WARNING: Could not detect OpenAI init or app.listen; appended registerAnalyzeImageRoute(app, openai) to end of file. Please verify manually." -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  registerAnalyzeImageRoute(app, openai) call already present." -ForegroundColor DarkGray
        }

        if ($backendChanged) {
            Set-Content -Path $serverFilePath -Value $serverLines -Encoding UTF8
            Write-Host "Backend server file updated." -ForegroundColor Green
        } else {
            Write-Host "No changes made to backend server file (already wired or skipped)." -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "=== Done: Confusion-AI screenshot upload wiring script completed. ===" -ForegroundColor Cyan
Write-Host "Backup directory: $backupDir" -ForegroundColor Cyan
Write-Host "Next: restart backend (npm start) and frontend (npm run dev), then refresh the page and look for the Screenshot analyzer block." -ForegroundColor Cyan
