param(
    [string]$BackendRoot = "."
)

$BackendRoot = (Resolve-Path $BackendRoot).Path
Write-Host "=== Confusion-AI backend OpenAI fix ===" -ForegroundColor Cyan
Write-Host "Backend root: $BackendRoot" -ForegroundColor Cyan

# 1) Backup backend
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupParent = Split-Path $BackendRoot -Parent
$backupDir = Join-Path $backupParent ("backup_backend_openai_" + $timestamp)

Write-Host "Creating backup at: $backupDir" -ForegroundColor Yellow
Copy-Item -Path $BackendRoot -Destination $backupDir -Recurse -Force
Write-Host "Backup complete." -ForegroundColor Green

$routePath = Join-Path $BackendRoot "analyzeImageRoute.js"
$indexPath = Join-Path $BackendRoot "index.js"

# 2) Rewrite analyzeImageRoute.js so it creates its own openai client
if (Test-Path $routePath) {
    Write-Host "Updating analyzeImageRoute.js to create its own OpenAI client..." -ForegroundColor Yellow

    $routeContent = @'
const OpenAI = require("openai");
const multer = require("multer");

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

function registerAnalyzeImageRoute(app) {
  if (!app) {
    throw new Error("registerAnalyzeImageRoute: app (Express) is required");
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
    Write-Host "analyzeImageRoute.js updated." -ForegroundColor Green
}
else {
    Write-Host "WARNING: analyzeImageRoute.js not found at $routePath" -ForegroundColor Yellow
}

# 3) Fix index.js call: registerAnalyzeImageRoute(app, openai) -> registerAnalyzeImageRoute(app)
if (Test-Path $indexPath) {
    Write-Host "Patching index.js to remove missing 'openai' argument..." -ForegroundColor Yellow

    $idxContent = Get-Content -Path $indexPath -Raw

    if ($idxContent -match "registerAnalyzeImageRoute\(app,\s*openai\)") {
        $idxContent = $idxContent -replace "registerAnalyzeImageRoute\(app,\s*openai\)", "registerAnalyzeImageRoute(app)"
        Set-Content -Path $indexPath -Value $idxContent -Encoding UTF8
        Write-Host "index.js updated: now calls registerAnalyzeImageRoute(app);" -ForegroundColor Green
    }
    else {
        Write-Host "No 'registerAnalyzeImageRoute(app, openai)' call found in index.js (maybe already fixed)." -ForegroundColor DarkGray
    }
}
else {
    Write-Host "WARNING: index.js not found at $indexPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done. Backend OpenAI reference fixed. ===" -ForegroundColor Cyan
Write-Host "Backup directory: $backupDir" -ForegroundColor Cyan
Write-Host "Now run:  npm start" -ForegroundColor Cyan
