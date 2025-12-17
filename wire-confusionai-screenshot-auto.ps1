param(
    # Frontend root (React + Vite). If you have a frontend folder, set -FrontendRoot ".\frontend"
    [string]$FrontendRoot = ".",

    # Backend root (Node + Express). If your backend is under backend/, leave as is.
    [string]$BackendRoot = ".\backend"
)

Write-Host "=== Confusion-AI Screenshot Auto-Wiring Script ===" -ForegroundColor Cyan

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

# 1) BACKUP
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $FrontendRoot -Parent
$backupDir = Join-Path $backupParent ("backup_confusionai_auto_" + $timestamp)

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
# 2) FRONTEND: FIND APP FILE & SRC ROOT
# ============================================================

Write-Host "Searching for App.tsx/App.jsx under frontend root..." -ForegroundColor Yellow
$appFile = Get-ChildItem -Path $FrontendRoot -Recurse -File -Include "App.tsx","App.jsx" | Select-Object -First 1

if (-not $appFile) {
    Write-Host "ERROR: Could not find App.tsx or App.jsx anywhere under $FrontendRoot." -ForegroundColor Red
    Write-Host "      If your main component is named differently, you'll need to wire ScreenshotUpload manually." -ForegroundColor Red
    Write-Host "      Backup directory: $backupDir" -ForegroundColor Cyan
    exit 1
}

$appPath = $appFile.FullName
Write-Host "Using app file: $appPath" -ForegroundColor Green

$appDir = Split-Path $appPath -Parent

# Try to find the 'src' root above the App file
$srcRoot = $appDir
while ((Split-Path $srcRoot -Leaf) -ne "src") {
    $parent = Split-Path $srcRoot -Parent
    if ($parent -eq $srcRoot) {
        break
    }
    $srcRoot = $parent
}

if ((Split-Path $srcRoot -Leaf) -ne "src") {
    Write-Host "Could not detect a 'src' folder above App. Using App directory as src root." -ForegroundColor Yellow
    $srcRoot = $appDir
} else {
    Write-Host "Detected src root: $srcRoot" -ForegroundColor Green
}

$componentsDir = Join-Path $srcRoot "components"
if (-not (Test-Path $componentsDir)) {
    Write-Host "Creating components directory at: $componentsDir" -ForegroundColor Yellow
    New-Item -Path $componentsDir -ItemType Directory | Out-Null
}

# ============================================================
# 3) FRONTEND: CREATE/OVERWRITE ScreenshotUpload.tsx
# ============================================================

$screenshotPath = Join-Path $componentsDir "ScreenshotUpload.tsx"
Write-Host "Writing ScreenshotUpload component to: $screenshotPath" -ForegroundColor Yellow

$screenshotComponentContent = @'
import React, { useState } from "react";

type ScreenshotUploadProps = {
  // Called with the JSON result from the backend
  onResult: (data: any) => void;
  // Optional: surface an error message to parent
  onError?: (message: string) => void;
};

const ScreenshotUpload: React.FC<ScreenshotUploadProps> = ({
  onResult,
  onError,
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selected = event.target.files?.[0] ?? null;
    if (!selected) return;

    if (!["image/png", "image/jpeg"].includes(selected.type)) {
      const message = "Please upload a PNG or JPG screenshot.";
      setError(message);
      setFile(null);
      setPreviewUrl(null);
      onError?.(message);
      return;
    }

    if (selected.size > 10 * 1024 * 1024) {
      const message = "File is too large. Max size is 10 MB.";
      setError(message);
      setFile(null);
      setPreviewUrl(null);
      onError?.(message);
      return;
    }

    setError(null);
    setFile(selected);
    const url = URL.createObjectURL(selected);
    setPreviewUrl(url);
  };

  const handleAnalyze = async () => {
    if (!file) return;

    setIsLoading(true);
    setError(null);

    const apiBase =
      import.meta.env.VITE_API_BASE_URL ?? "http://localhost:5000";

    const formData = new FormData();
    formData.append("image", file);

    try {
      const response = await fetch(`${apiBase}/analyze-image`, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const text = await response.text();
        const message =
          text || `Screenshot analysis failed with status ${response.status}.`;
        setError(message);
        onError?.(message);
        return;
      }

      const data = await response.json();
      onResult(data);
    } catch (err: unknown) {
      const message =
        err instanceof Error
          ? err.message
          : "Unexpected error while analyzing screenshot.";
      setError(message);
      onError?.(message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="mt-4 flex flex-col gap-3 rounded-2xl border border-slate-700 bg-slate-900/60 p-4">
      <div className="flex items-center justify-between gap-2">
        <h3 className="text-sm font-semibold text-slate-100">
          Screenshot analyzer
        </h3>
        {isLoading && (
          <span className="animate-pulse text-xs text-amber-400">
            Analyzing screenshot...
          </span>
        )}
      </div>

      <label className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-600 bg-slate-950/40 px-4 py-6 text-center transition hover:border-emerald-400 hover:bg-slate-900/70">
        <span className="text-xs text-slate-300">
          Drop a text-message screenshot here or click to browse
        </span>
        <span className="text-[10px] uppercase tracking-wide text-slate-500">
          PNG or JPG • up to 10 MB
        </span>
        <input
          type="file"
          accept="image/png,image/jpeg"
          className="hidden"
          onChange={handleFileChange}
        />
      </label>

      {previewUrl && (
        <div className="flex items-center gap-3">
          <img
            src={previewUrl}
            alt="Screenshot preview"
            className="h-20 w-auto rounded-lg border border-slate-700 object-cover"
          />
          <div className="flex flex-1 flex-col gap-2">
            <p className="truncate text-xs text-slate-300">
              {file?.name ?? "Selected screenshot"}
            </p>
            <button
              type="button"
              onClick={handleAnalyze}
              disabled={isLoading}
              className="inline-flex items-center justify-center rounded-lg border border-emerald-500/60 bg-emerald-500/80 px-3 py-1.5 text-xs font-medium text-slate-950 shadow-md shadow-emerald-900/40 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {isLoading ? "Analyzing..." : "Analyze Screenshot"}
            </button>
          </div>
        </div>
      )}

      {error && (
        <p className="text-xs text-red-400">
          {error}
        </p>
      )}

      {!previewUrl && (
        <p className="text-[11px] text-slate-400">
          Tip: Use this when you&apos;re too lazy to copy/paste the chat.
          Just upload a clear screenshot of the messages.
        </p>
      )}
    </div>
  );
};

export default ScreenshotUpload;
'@

Set-Content -Path $screenshotPath -Value $screenshotComponentContent -Encoding UTF8

# ============================================================
# 4) FRONTEND: WIRE INTO APP (IMPORT + JSX)
# ============================================================

Write-Host "Wiring ScreenshotUpload into App file..." -ForegroundColor Yellow

$appContent = Get-Content -Path $appPath -Raw
$frontendChanged = $false

# 4a) Ensure import
if ($appContent -notmatch "ScreenshotUpload") {
    Write-Host "  Adding import for ScreenshotUpload..." -ForegroundColor Yellow

    $importLine = 'import ScreenshotUpload from "./components/ScreenshotUpload";'
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

# 4b) Inject JSX snippet
if ($appContent -notmatch "<ScreenshotUpload") {
    Write-Host "  Injecting <ScreenshotUpload ... /> snippet..." -ForegroundColor Yellow

    # Try to detect setter name
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
        Write-Host "WARNING: Could not detect analysis setter. Using console.log in onResult." -ForegroundColor Yellow
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
        Write-Host "WARNING: Could not find </main> or </div> to inject ScreenshotUpload. Please add it manually in your JSX." -ForegroundColor Yellow
    }
} else {
    Write-Host "  ScreenshotUpload JSX already present in App file." -ForegroundColor DarkGray
}

if ($frontendChanged) {
    Set-Content -Path $appPath -Value $appContent -Encoding UTF8
    Write-Host "App file updated with ScreenshotUpload wiring." -ForegroundColor Green
} else {
    Write-Host "No changes were needed for the App file (it may already be wired)." -ForegroundColor DarkGray
}

# ============================================================
# 5) FRONTEND .ENV: VITE_API_BASE_URL
# ============================================================

$envPath = Join-Path $FrontendRoot ".env"

if (Test-Path $envPath) {
    Write-Host "Checking .env for VITE_API_BASE_URL..." -ForegroundColor Yellow
    $envContent = Get-Content -Path $envPath -Raw
    if ($envContent -notmatch "VITE_API_BASE_URL") {
        Write-Host "  Adding VITE_API_BASE_URL to existing .env" -ForegroundColor Yellow
        Add-Content -Path $envPath -Value "`r`n# Confusion-AI backend base URL`r`nVITE_API_BASE_URL=http://localhost:5000"
        Write-Host "  Default set to http://localhost:5000 (change if using Render)." -ForegroundColor Green
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
# 6) BACKEND: ROUTE + WIRING (if backend exists)
# ============================================================

if ($BackendRoot) {
    $packageJsonPath = Join-Path $BackendRoot "package.json"
    if (-not (Test-Path $packageJsonPath)) {
        Write-Host "Backend package.json not found under $BackendRoot. Skipping backend wiring." -ForegroundColor Yellow
    } else {
        Write-Host "Configuring backend /analyze-image route..." -ForegroundColor Yellow

        # Install multer + openai
        Write-Host "  Ensuring multer & openai are installed..." -ForegroundColor Yellow
        Push-Location $BackendRoot
        try {
            npm install multer openai | Out-Null
        } catch {
            Write-Host "  npm install failed. Please check backend manually." -ForegroundColor Red
        }
        Pop-Location

        $routePath = Join-Path $BackendRoot "analyzeImageRoute.js"
        if (-not (Test-Path $routePath)) {
            Write-Host "  Creating analyzeImageRoute.js..." -ForegroundColor Yellow
            $routeContent = @'
const multer = require("multer");

/**
 * Registers the /analyze-image endpoint on your existing Express app.
 *
 * Expected usage in your main server file (CommonJS example):
 *
 *   const { registerAnalyzeImageRoute } = require("./analyzeImageRoute");
 *   registerAnalyzeImageRoute(app, openai);
 *
 * Where:
 *   - app   is your Express app instance
 *   - openai is an OpenAI client (e.g. new OpenAI({ apiKey: process.env.OPENAI_API_KEY }))
 */

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

function registerAnalyzeImageRoute(app, openai) {
  if (!app) {
    throw new Error("registerAnalyzeImageRoute: app (Express) is required");
  }
  if (!openai) {
    throw new Error("registerAnalyzeImageRoute: openai client is required");
  }

  app.post("/analyze-image", upload.single("image"), async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: "No image uploaded" });
      }

      const mimeType = req.file.mimetype || "image/png";
      const base64 = req.file.buffer.toString("base64");

      const prompt = `
You are Confusion-AI, an AI that analyzes conversations.

You will be given a screenshot of a text message conversation.

1. Read the messages and reconstruct the conversation.
2. Return STRICT JSON with the following shape:
{
  "honesty": { "score": number, "reason": string },
  "gaslighting": { "score": number, "reason": string },
  "hiddenAgenda": { "score": number, "reason": string },
  "miscommunication": { "score": number, "reason": string },
  "inLove": { "score": number, "reason": string },
  "flirting": { "score": number, "reason": string },
  "shy": { "score": number, "reason": string },
  "summary": string
}
Scores are 0–100.
Only output JSON, no backticks, no explanation.
`;

      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You analyze conversations and output ONLY valid JSON.",
          },
          {
            role: "user",
            content: [
              {
                type: "text",
                text: prompt,
              },
              {
                type: "image_url",
                image_url: {
                  url: `data:${mimeType};base64,${base64}`,
                },
              },
            ],
          },
        ],
      });

      const content = response.choices?.[0]?.message?.content || "{}";

      let parsed;
      try {
        parsed = JSON.parse(content);
      } catch (err) {
        console.error("Failed to parse JSON from model:", err);
        return res.status(500).json({
          error: "Failed to parse JSON from model",
          raw: content,
        });
      }

      return res.json(parsed);
    } catch (err) {
      console.error("Error in /analyze-image:", err);
      return res.status(500).json({ error: "Failed to analyze image" });
    }
  });

  console.log("✓ /analyze-image route registered");
}

module.exports = { registerAnalyzeImageRoute };
'@
            Set-Content -Path $routePath -Value $routeContent -Encoding UTF8
        } else {
            Write-Host "  analyzeImageRoute.js already exists; leaving it as is." -ForegroundColor DarkGray
        }

        # Find main server file
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
            Write-Host "  WARNING: Could not find server.js/index.js/app.js/main.js in backend root. Skipping server wiring." -ForegroundColor Yellow
        } else {
            Write-Host "  Wiring backend server file: $serverFilePath" -ForegroundColor Yellow
            $serverLines = Get-Content -Path $serverFilePath
            $backendChanged = $false
            $serverJoined = $serverLines -join "`n"

            # Ensure require
            if ($serverJoined -notmatch "registerAnalyzeImageRoute") {
                Write-Host "    Adding require('./analyzeImageRoute')..." -ForegroundColor Yellow
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
                Write-Host "    analyzeImageRoute require already present." -ForegroundColor DarkGray
            }

            $serverJoined = $serverLines -join "`n"

            # Ensure registerAnalyzeImageRoute(app, openai) call
            if ($serverJoined -notmatch "registerAnalyzeImageRoute\(app,\s*openai\)") {
                Write-Host "    Adding registerAnalyzeImageRoute(app, openai) call..." -ForegroundColor Yellow
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
                    Write-Host "      Inserted after OpenAI initialization." -ForegroundColor Green
                } else {
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
                        Write-Host "      Inserted before app.listen(...)." -ForegroundColor Green
                    } else {
                        $serverLines += $callLine
                        $backendChanged = $true
                        Write-Host "      WARNING: Could not detect OpenAI init or app.listen; appended call at end of file. Please verify manually." -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "    registerAnalyzeImageRoute(app, openai) call already present." -ForegroundColor DarkGray
            }

            if ($backendChanged) {
                Set-Content -Path $serverFilePath -Value $serverLines -Encoding UTF8
                Write-Host "  Backend server file updated." -ForegroundColor Green
            } else {
                Write-Host "  No changes needed for backend server file." -ForegroundColor DarkGray
            }
        }
    }
}

Write-Host ""
Write-Host "=== Done: Confusion-AI screenshot upload auto-wiring complete. ===" -ForegroundColor Cyan
Write-Host "Backup directory: $backupDir" -ForegroundColor Cyan
Write-Host "Now restart backend (npm start) and frontend (npm run dev), then refresh and look for the 'Screenshot analyzer' block." -ForegroundColor Cyan
