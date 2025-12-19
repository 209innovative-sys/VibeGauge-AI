param(
    # Frontend root (React + Vite)
    [string]$FrontendRoot = ".",

    # Backend root (Node + Express). Change if your backend lives elsewhere.
    [string]$BackendRoot = ".\backend"
)

Write-Host "=== Confusion-AI Screenshot Upload + Vision Setup ===" -ForegroundColor Cyan

# Resolve frontend root
$FrontendRoot = (Resolve-Path $FrontendRoot).Path
Write-Host "Frontend root: $FrontendRoot" -ForegroundColor Cyan

# Resolve backend root if it exists
if (Test-Path $BackendRoot) {
    $BackendRoot = (Resolve-Path $BackendRoot).Path
    Write-Host "Backend root:  $BackendRoot" -ForegroundColor Cyan
} else {
    Write-Host "Backend root '$BackendRoot' not found. Backend steps will be skipped." -ForegroundColor Yellow
    $BackendRoot = $null
}

# 1. Backup both frontend and backend
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $FrontendRoot -Parent
$backupDir = Join-Path $backupParent ("backup_confusionai_vision_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

# Backup frontend
$frontendBackup = Join-Path $backupDir "frontend"
Copy-Item -Path $FrontendRoot -Destination $frontendBackup -Recurse -Force

# Backup backend (if present)
if ($BackendRoot) {
    $backendBackup = Join-Path $backupDir "backend"
    Copy-Item -Path $BackendRoot -Destination $backendBackup -Recurse -Force
}

Write-Host "Backup created." -ForegroundColor Green

# 2. FRONTEND: create ScreenshotUpload.tsx component
$componentsDir = Join-Path $FrontendRoot "src\components"
if (-not (Test-Path $componentsDir)) {
    Write-Host "Creating src/components directory..." -ForegroundColor Yellow
    New-Item -Path $componentsDir -ItemType Directory | Out-Null
}

$screenshotComponentPath = Join-Path $componentsDir "ScreenshotUpload.tsx"
if (Test-Path $screenshotComponentPath) {
    Write-Host "ScreenshotUpload.tsx already exists. It will be overwritten." -ForegroundColor Yellow
}

Write-Host "Writing src/components/ScreenshotUpload.tsx..." -ForegroundColor Yellow

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

Set-Content -Path $screenshotComponentPath -Value $screenshotComponentContent -Encoding UTF8

# 3. FRONTEND: ensure .env.example has VITE_API_BASE_URL
$envExamplePath = Join-Path $FrontendRoot ".env.example"
if (Test-Path $envExamplePath) {
    Write-Host "Updating .env.example with VITE_API_BASE_URL (if missing)..." -ForegroundColor Yellow
    $envContent = Get-Content $envExamplePath -Raw
    if ($envContent -notmatch "VITE_API_BASE_URL") {
        Add-Content -Path $envExamplePath -Value "`r`n# Base URL for Confusion-AI backend`r`nVITE_API_BASE_URL=http://localhost:5000"
    }
} else {
    Write-Host "Creating .env.example with VITE_API_BASE_URL..." -ForegroundColor Yellow
    $envTemplate = @'
# Confusion-AI frontend environment
VITE_API_BASE_URL=http://localhost:5000
'@
    Set-Content -Path $envExamplePath -Value $envTemplate -Encoding UTF8
}

# 4. BACKEND: add /analyze-image route file (if backend root is present and looks like a Node project)
if ($BackendRoot -and (Test-Path (Join-Path $BackendRoot "package.json"))) {
    Write-Host "Configuring backend analyze-image route..." -ForegroundColor Yellow

    # Install multer + openai (if not already present)
    Write-Host "Installing multer and ensuring openai is installed..." -ForegroundColor Yellow
    Push-Location $BackendRoot
    try {
        npm install multer openai | Out-Null
    } catch {
        Write-Host "npm install failed. Please check backend manually." -ForegroundColor Red
    }
    Pop-Location

    $routePath = Join-Path $BackendRoot "analyzeImageRoute.js"
    Write-Host "Writing $routePath ..." -ForegroundColor Yellow

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
    Write-Host "Backend package.json not found. Skipping backend route setup." -ForegroundColor Yellow
}

Write-Host "=== Done: Screenshot upload component + backend route file created. ===" -ForegroundColor Cyan
Write-Host "Backup is at: $backupDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "NEXT STEPS (manual wiring):" -ForegroundColor Green
Write-Host "1) FRONTEND:" -ForegroundColor Green
Write-Host "   - Open src/App.tsx (or your main page component)." -ForegroundColor Green
Write-Host "   - Import the component:" -ForegroundColor Green
Write-Host '       import ScreenshotUpload from "./components/ScreenshotUpload";' -ForegroundColor Green
Write-Host "   - Render it near your existing text-analysis UI and pass your result handler:" -ForegroundColor Green
Write-Host '       <ScreenshotUpload onResult={setAnalysisResult} />' -ForegroundColor Green
Write-Host "     (Replace setAnalysisResult with whatever you use to store the analysis JSON.)" -ForegroundColor Green

Write-Host ""
Write-Host "2) BACKEND:" -ForegroundColor Green
Write-Host "   - Open your main Express server file (e.g., server.js or index.js)." -ForegroundColor Green
Write-Host "   - After you create 'app' and 'openai', add:" -ForegroundColor Green
Write-Host '       const { registerAnalyzeImageRoute } = require("./analyzeImageRoute");' -ForegroundColor Green
Write-Host '       registerAnalyzeImageRoute(app, openai);' -ForegroundColor Green
Write-Host "   - Make sure OPENAI_API_KEY is set in your backend env." -ForegroundColor Green

Write-Host ""
Write-Host "3) FRONTEND ENV:" -ForegroundColor Green
Write-Host "   - In your frontend .env (not committed), set:" -ForegroundColor Green
Write-Host "       VITE_API_BASE_URL=http://localhost:5000   (or your Render URL)" -ForegroundColor Green
Write-Host ""
Write-Host "Then restart both backend and frontend, upload a screenshot, and you should get Confusion-AI metrics back." -ForegroundColor Cyan
