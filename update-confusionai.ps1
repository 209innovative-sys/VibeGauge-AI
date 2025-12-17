param(
    [string]$ProjectRoot = "."
)

$ProjectRoot = (Resolve-Path $ProjectRoot).Path

Write-Host "=== Confusion-AI bulk updater ===" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot" -ForegroundColor Cyan

# 1. Backup the project
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $ProjectRoot -Parent
$backupDir = Join-Path $backupParent ("backup_confusionai_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
Copy-Item -Path $ProjectRoot -Destination $backupDir -Recurse -Force

# 2. Rename app strings to Confusion-AI
$newName = "Confusion-AI"
$oldNames = @(
    "Aura AI",
    "Aura-AI",
    "AuraAI",
    "VibeGauge-AI",
    "VibeGauge AI",
    "VibeGaugeAI",
    "VibeGauge"
)

$extensions = @("*.tsx","*.ts","*.jsx","*.js","*.html","*.css","*.md","*.json","*.env","*.txt")

Write-Host "Renaming app to '$newName' in source files..." -ForegroundColor Yellow

foreach ($pattern in $extensions) {
    Get-ChildItem -Path $ProjectRoot -Recurse -File -Include $pattern | ForEach-Object {
        $file = $_.FullName
        $content = Get-Content $file -Raw
        $original = $content
        foreach ($old in $oldNames) {
            if ($content -like "*$old*") {
                $content = $content.Replace($old, $newName)
            }
        }
        if ($content -ne $original) {
            Set-Content -Path $file -Value $content -Encoding UTF8
            Write-Host "  Updated names in $($file.Substring($ProjectRoot.Length))"
        }
    }
}

# 3. Update index.html: <title> + graffiti font
$indexHtmlPath = Join-Path $ProjectRoot "index.html"
if (Test-Path $indexHtmlPath) {
    Write-Host "Updating index.html title and font link..." -ForegroundColor Yellow
    $html = Get-Content $indexHtmlPath -Raw
    $changed = $false

    if ($html -match "<title>.*?</title>") {
        $html = [regex]::Replace($html, "<title>.*?</title>", "<title>Confusion-AI</title>", 1)
        $changed = $true
    }
    elseif ($html -match "</head>") {
        $html = $html -replace "</head>", "  <title>Confusion-AI</title>`r`n</head>"
        $changed = $true
    }

    $fontLink = '<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet">'
    if ($html -notlike "*$fontLink*") {
        if ($html -match "</head>") {
            $html = $html -replace "</head>", "  $fontLink`r`n</head>"
            $changed = $true
        }
    }

    if ($changed) {
        Set-Content -Path $indexHtmlPath -Value $html -Encoding UTF8
        Write-Host "  index.html updated."
    }
    else {
        Write-Host "  No changes needed for index.html." -ForegroundColor DarkGray
    }
}
else {
    Write-Host "index.html not found, skipping title/font update." -ForegroundColor DarkGray
}

# 4. Ensure src/components exists
$componentsDir = Join-Path $ProjectRoot "src\components"
if (-not (Test-Path $componentsDir)) {
    Write-Host "Creating src/components directory..." -ForegroundColor Yellow
    New-Item -Path $componentsDir -ItemType Directory | Out-Null
}

# 5. Create / overwrite BrandWatermark.tsx
$brandComponentPath = Join-Path $componentsDir "BrandWatermark.tsx"
Write-Host "Writing BrandWatermark.tsx (Innovative Solutions graffiti watermark)..." -ForegroundColor Yellow

$brandComponentContent = @'
import React from "react";

const BrandWatermark: React.FC = () => {
  return (
    <div
      className="fixed bottom-4 right-4 z-50 text-xs sm:text-sm md:text-base text-white/80 select-none pointer-events-none"
      style={{
        fontFamily: "'Pacifico','Brush Script MT',cursive",
        textShadow:
          "0 0 4px rgba(0,0,0,0.9), 0 0 14px rgba(255,255,255,0.6)",
      }}
    >
      <span className="px-4 py-2 rounded-full bg-black/60 backdrop-blur-md border border-white/20 shadow-lg shadow-black/60 tracking-wide">
        Innovative Solutions
      </span>
    </div>
  );
};

export default BrandWatermark;
'@

Set-Content -Path $brandComponentPath -Value $brandComponentContent -Encoding UTF8

# 6. Wire BrandWatermark into src/App.tsx
$appPath = Join-Path $ProjectRoot "src\App.tsx"
if (Test-Path $appPath) {
    Write-Host "Injecting BrandWatermark into App.tsx..." -ForegroundColor Yellow
    $appContent = Get-Content $appPath -Raw
    $updated = $false

    if ($appContent -notmatch "BrandWatermark") {
        $importLine = 'import BrandWatermark from "./components/BrandWatermark";'
        $appContent = $importLine + "`r`n" + $appContent
        $updated = $true
    }

    if ($appContent -match "return\s*\(" -and $appContent -notmatch "<BrandWatermark\s*/>") {
        $regex = New-Object System.Text.RegularExpressions.Regex(
            "\r?\n\)\s*;",
            [System.Text.RegularExpressions.RegexOptions]::RightToLeft
        )

        $newAppContent = $regex.Replace($appContent, "`r`n  <BrandWatermark />`r`n);", 1)

        if ($newAppContent -ne $appContent) {
            $appContent = $newAppContent
            $updated = $true
        }
    }

    if ($updated) {
        Set-Content -Path $appPath -Value $appContent -Encoding UTF8
        Write-Host "  App.tsx updated with Confusion-AI watermark." -ForegroundColor Green
    }
    else {
        Write-Host "  Could not safely inject <BrandWatermark /> automatically." -ForegroundColor Yellow
        Write-Host "  Add it manually inside your main App component's JSX:" -ForegroundColor Yellow
        Write-Host "    <BrandWatermark />" -ForegroundColor Yellow
    }
}
else {
    Write-Host "src\App.tsx not found. Please import and render <BrandWatermark /> in your root layout manually." -ForegroundColor Yellow
}

Write-Host "=== Done: app renamed to Confusion-AI and 'Innovative Solutions' watermark added. ===" -ForegroundColor Cyan
Write-Host "A full backup was created at: $backupDir" -ForegroundColor Cyan
