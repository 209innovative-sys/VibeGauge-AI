param(
  [string]$RepoRoot = ".",
  [string]$FrontendDir = "frontend",
  [string]$BackendDir = "backend"
)

Write-Host "=== Confusion-AI: Monetization + Chat UI Phase 1 ===" -ForegroundColor Cyan

# Resolve repo root
try {
  $rootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
}
catch {
  Write-Error "Repo root not found: $RepoRoot"
  exit 1
}

Set-Location $rootPath
Write-Host "Repo root: $rootPath" -ForegroundColor Yellow

$frontendPath = Join-Path $rootPath $FrontendDir
$backendPath = Join-Path $rootPath $BackendDir
$srcPath = Join-Path $frontendPath "src"
$componentsDir = Join-Path $srcPath "components"

if (-not (Test-Path $frontendPath)) {
  Write-Error "Frontend directory not found: $frontendPath"
  exit 1
}
if (-not (Test-Path $backendPath)) {
  Write-Error "Backend directory not found: $backendPath"
  exit 1
}
if (-not (Test-Path $srcPath)) {
  New-Item -ItemType Directory -Path $srcPath -ErrorAction SilentlyContinue | Out-Null
}
if (-not (Test-Path $componentsDir)) {
  New-Item -ItemType Directory -Path $componentsDir -ErrorAction SilentlyContinue | Out-Null
}

$appPath = Join-Path $srcPath "App.tsx"
$screenshotPath = Join-Path $componentsDir "ScreenshotUpload.tsx"
$convoPreviewPath = Join-Path $componentsDir "ConversationPreview.tsx"
$indexPath = Join-Path $backendPath "index.js"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# -------------------------------------------------------------------
# Backups
# -------------------------------------------------------------------
$backupFrontendDir = Join-Path $rootPath ("backup_frontend_confusionai_monetization_" + $timestamp)
$backupBackendDir = Join-Path $rootPath ("backup_backend_confusionai_monetization_" + $timestamp)

Write-Host "Backing up frontend files to: $backupFrontendDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $backupFrontendDir -ErrorAction SilentlyContinue | Out-Null
if (Test-Path $appPath) { Copy-Item -Path $appPath          -Destination (Join-Path $backupFrontendDir "App.tsx") -Force }
if (Test-Path $screenshotPath) { Copy-Item -Path $screenshotPath   -Destination (Join-Path $backupFrontendDir "ScreenshotUpload.tsx") -Force }
if (Test-Path $convoPreviewPath) { Copy-Item -Path $convoPreviewPath -Destination (Join-Path $backupFrontendDir "ConversationPreview.tsx") -Force }
Write-Host "Frontend backup complete." -ForegroundColor Green

Write-Host "Backing up backend to: $backupBackendDir" -ForegroundColor Yellow
Copy-Item -Path $backendPath -Destination $backupBackendDir -Recurse -Force
Write-Host "Backend backup complete." -ForegroundColor Green

# -------------------------------------------------------------------
# backend/index.js (Stripe-ready + OpenAI analysis)
# -------------------------------------------------------------------
Write-Host "Writing backend index.js to: $indexPath" -ForegroundColor Yellow

$indexContent = @'
/**
 * Confusion-AI Backend
 * - /analyze         : Text compatibility analysis
 * - /analyze-image   : Screenshot compatibility analysis
 * - /create-checkout-session : Stripe checkout for Pro
 *
 * backend/.env example:
 *   OPENAI_API_KEY=sk-...
 *   PORT=4000
 *   CORS_ORIGIN=http://localhost:5173,http://localhost:5174
 *   OPENAI_TEXT_MODEL=gpt-4o-mini
 *   OPENAI_IMAGE_MODEL=gpt-4o-mini
 *   STRIPE_SECRET_KEY=sk_live_xxx_or_test_key
 *   STRIPE_PRICE_ID=price_xxx
 *   APP_BASE_URL=http://localhost:5173
 */

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const multer = require("multer");
const { OpenAI } = require("openai");
const Stripe = require("stripe");

const app = express();
const port = process.env.PORT || 4000;

if (!process.env.OPENAI_API_KEY) {
  console.warn(
    "[Confusion-AI] WARNING: OPENAI_API_KEY is not set. /analyze and /analyze-image will fail."
  );
}

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const stripeSecretKey = process.env.STRIPE_SECRET_KEY || "";
const stripe = stripeSecretKey ? new Stripe(stripeSecretKey) : null;
const stripePriceId = process.env.STRIPE_PRICE_ID || "";
const appBaseUrl = process.env.APP_BASE_URL || "http://localhost:5173";

// ----- CORS -----
const allowedOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(",").map((s) => s.trim())
  : ["*"];

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes("*") || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error("Not allowed by CORS"), false);
    },
    credentials: true,
  })
);

// ----- JSON body -----
app.use(
  express.json({
    limit: "2mb",
  })
);

// ----- Multer for image upload -----
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 8 * 1024 * 1024, // 8MB
  },
});

// ----- Helpers -----
function buildSystemPrompt() {
  return `
You are Confusion-AI, a compatibility and vibe analyzer for human conversations.

Your job:
- Read a conversation (either as text or extracted from a screenshot).
- Analyze it for:
  - honesty
  - gaslighting
  - hiddenAgenda
  - miscommunication
  - inLove
  - flirting
  - shy
- Then produce a compatibility summary.

Return ONLY valid JSON with this exact shape:

{
  "honesty":       { "score": number, "reason": string },
  "gaslighting":   { "score": number, "reason": string },
  "hiddenAgenda":  { "score": number, "reason": string },
  "miscommunication": { "score": number, "reason": string },
  "inLove":        { "score": number, "reason": string },
  "flirting":      { "score": number, "reason": string },
  "shy":           { "score": number, "reason": string },
  "summary":       string
}

Where:
- All scores are from 0 to 100.
- Higher honesty = more honest.
- Higher gaslighting = more gaslighting.
- Higher hiddenAgenda = more hidden agenda / manipulation.
- Higher miscommunication = more confusion and missing each other.
- Higher inLove = more romantic / attached feelings.
- Higher flirting = more playful romantic or sexual energy.
- Higher shy = more timid, indirect communication.

Be concise but concrete in the "reason" fields.
Use the conversation content only; do not add external facts.
  `.trim();
}

function extractContent(messageContent) {
  if (Array.isArray(messageContent)) {
    return messageContent.map((part) => part.text ?? "").join("");
  }
  return messageContent || "{}";
}

function safeParseJSON(raw) {
  try {
    return JSON.parse(raw);
  } catch (err) {
    console.error("[Confusion-AI] JSON parse error:", err);
    return null;
  }
}

function normalizeMetric(raw) {
  if (!raw || typeof raw !== "object") {
    return {
      score: 0,
      reason: "No signal detected.",
    };
  }
  const score = Number(raw.score);
  const capped = Number.isFinite(score)
    ? Math.max(0, Math.min(100, score))
    : 0;

  const reason =
    typeof raw.reason === "string" && raw.reason.trim().length > 0
      ? raw.reason.trim()
      : "No detailed explanation provided.";

  return { score: capped, reason };
}

function normalizeAnalysis(data) {
  if (!data || typeof data !== "object") {
    return {
      honesty: { score: 0, reason: "No data (fallback)." },
      gaslighting: { score: 0, reason: "No data (fallback)." },
      hiddenAgenda: { score: 0, reason: "No data (fallback)." },
      miscommunication: { score: 0, reason: "No data (fallback)." },
      inLove: { score: 0, reason: "No data (fallback)." },
      flirting: { score: 0, reason: "No data (fallback)." },
      shy: { score: 0, reason: "No data (fallback)." },
      summary:
        "Analysis did not return valid JSON. This is a safe fallback response.",
    };
  }

  return {
    honesty: normalizeMetric(data.honesty),
    gaslighting: normalizeMetric(data.gaslighting),
    hiddenAgenda: normalizeMetric(data.hiddenAgenda),
    miscommunication: normalizeMetric(data.miscommunication),
    inLove: normalizeMetric(data.inLove),
    flirting: normalizeMetric(data.flirting),
    shy: normalizeMetric(data.shy),
    summary:
      typeof data.summary === "string" && data.summary.trim().length > 0
        ? data.summary.trim()
        : "No summary provided.",
  };
}

async function withTimeout(promise, ms, label) {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${label || "Operation"} timed out after ${ms}ms`));
    }, ms);
  });

  try {
    const result = await Promise.race([promise, timeoutPromise]);
    clearTimeout(timeoutId);
    return result;
  } catch (err) {
    clearTimeout(timeoutId);
    throw err;
  }
}

// ----- Core analysis helpers -----
async function analyzeConversationText(text) {
  const model = process.env.OPENAI_TEXT_MODEL || "gpt-4o-mini";

  const request = openai.chat.completions.create({
    model,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: buildSystemPrompt(),
      },
      {
        role: "user",
        content: `Here is the conversation to analyze for compatibility and vibe:\\n\\n${text}`,
      },
    ],
  });

  const response = await withTimeout(
    request,
    60000,
    "OpenAI text analysis"
  );

  const rawContent = extractContent(response.choices?.[0]?.message?.content);
  const parsed = safeParseJSON(rawContent);
  return normalizeAnalysis(parsed);
}

async function analyzeConversationImage(buffer, mimeType) {
  const model = process.env.OPENAI_IMAGE_MODEL || "gpt-4o-mini";

  const base64 = buffer.toString("base64");
  const safeMime = mimeType || "image/png";

  const request = openai.chat.completions.create({
    model,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: buildSystemPrompt(),
      },
      {
        role: "user",
        content: [
          {
            type: "text",
            text:
              "First, carefully read and transcribe the text conversation from this screenshot. " +
              "Then analyze the conversation for compatibility and vibe as described in the system prompt. " +
              "Finally, return ONLY the JSON object in the required structure.",
          },
          {
            type: "image_url",
            image_url: {
              url: `data:${safeMime};base64,${base64}`,
            },
          },
        ],
      },
    ],
  });

  const response = await withTimeout(
    request,
    60000,
    "OpenAI image analysis"
  );

  const rawContent = extractContent(response.choices?.[0]?.message?.content);
  const parsed = safeParseJSON(rawContent);
  return normalizeAnalysis(parsed);
}

// ----- Routes -----
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "confusion-ai-backend",
    timestamp: new Date().toISOString(),
  });
});

app.post("/analyze", async (req, res) => {
  console.log("[/analyze] Incoming text analysis request");
  try {
    const text = req.body?.text;
    if (!text || typeof text !== "string" || !text.trim()) {
      return res.status(400).json({
        error: "Missing or empty 'text' field in request body.",
      });
    }

    const result = await analyzeConversationText(text.trim());
    console.log("[/analyze] Completed OK");
    return res.json(result);
  } catch (err) {
    console.error("[/analyze] Error:", err);
    return res.status(500).json({
      error: "Failed to analyze text conversation.",
    });
  }
});

app.post(
  "/analyze-image",
  upload.single("image"),
  async (req, res) => {
    console.log("[/analyze-image] Incoming screenshot analysis request");
    try {
      if (!req.file || !req.file.buffer) {
        return res.status(400).json({
          error: "Missing image file field 'image'.",
        });
      }

      const result = await analyzeConversationImage(
        req.file.buffer,
        req.file.mimetype
      );
      console.log("[/analyze-image] Completed OK");
      return res.json(result);
    } catch (err) {
      console.error("[/analyze-image] Error:", err);
      return res.status(500).json({
        error: "Failed to analyze screenshot conversation.",
      });
    }
  }
);

// Stripe checkout session (Pro upgrade)
app.post("/create-checkout-session", async (req, res) => {
  if (!stripe || !stripePriceId) {
    console.error("[/create-checkout-session] Stripe not configured.");
    return res.status(500).json({
      error:
        "Stripe not configured. Set STRIPE_SECRET_KEY and STRIPE_PRICE_ID in backend .env.",
    });
  }

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [
        {
          price: stripePriceId,
          quantity: 1,
        },
      ],
      success_url: `${appBaseUrl}/?plan=pro&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${appBaseUrl}/?plan=free`,
    });

    return res.json({ url: session.url });
  } catch (err) {
    console.error("[/create-checkout-session] Error:", err);
    return res.status(500).json({
      error: "Failed to create checkout session.",
    });
  }
});

app.listen(port, () => {
  console.log(
    `[Confusion-AI] Backend listening on port ${port}. /analyze, /analyze-image, and /create-checkout-session ready.`
  );
});
'@

Set-Content -Path $indexPath -Value $indexContent -Encoding UTF8
Write-Host "backend/index.js written." -ForegroundColor Green

# -------------------------------------------------------------------
# Install backend deps (idempotent)
# -------------------------------------------------------------------
Write-Host "Installing backend dependencies (openai, multer, cors, dotenv, stripe)..." -ForegroundColor Yellow
Push-Location $backendPath
npm install openai multer cors dotenv stripe --save
Pop-Location
Write-Host "Backend dependencies installed (or already present)." -ForegroundColor Green

# -------------------------------------------------------------------
# frontend/src/components/ConversationPreview.tsx
# -------------------------------------------------------------------
Write-Host "Writing ConversationPreview.tsx to: $convoPreviewPath" -ForegroundColor Yellow

$convoPreviewContent = @'
import React from "react";

type ConversationPreviewProps = {
  rawText: string;
};

type Bubble = {
  id: number;
  from: "A" | "B";
  text: string;
};

const parseConversation = (rawText: string): Bubble[] => {
  const lines = rawText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  return lines.map((text, index) => ({
    id: index,
    from: index % 2 === 0 ? "A" : "B",
    text,
  }));
};

const ConversationPreview: React.FC<ConversationPreviewProps> = ({ rawText }) => {
  const bubbles = parseConversation(rawText);

  if (bubbles.length === 0) {
    return (
      <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3 text-[11px] text-slate-500">
        Conversation preview will appear here in a chat-style layout once you paste
        messages above.
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3">
      <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-slate-400">
        Conversation preview
      </div>
      <div className="max-h-64 space-y-1.5 overflow-y-auto pr-1 text-[11px]">
        {bubbles.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${
              msg.from === "A" ? "justify-start" : "justify-end"
            }`}
          >
            <div
              className={`max-w-[80%] rounded-2xl px-3 py-1.5 ${
                msg.from === "A"
                  ? "bg-slate-800 text-slate-100"
                  : "bg-emerald-500 text-slate-950"
              }`}
            >
              <p className="whitespace-pre-wrap leading-snug">{msg.text}</p>
            </div>
          </div>
        ))}
      </div>
      <p className="mt-2 text-[10px] text-slate-500">
        This is a visual preview only. The AI uses the raw text you pasted for
        compatibility analysis.
      </p>
    </div>
  );
};

export default ConversationPreview;
'@

Set-Content -Path $convoPreviewPath -Value $convoPreviewContent -Encoding UTF8
Write-Host "ConversationPreview.tsx written." -ForegroundColor Green

# -------------------------------------------------------------------
# frontend/src/components/ScreenshotUpload.tsx (add gating via canAnalyze)
# -------------------------------------------------------------------
Write-Host "Writing ScreenshotUpload.tsx to: $screenshotPath" -ForegroundColor Yellow

$screenshotContent = @'
import React, { useEffect, useState } from "react";

type Metric = {
  score: number;
  reason: string;
};

type AnalysisResult = {
  honesty: Metric;
  gaslighting: Metric;
  hiddenAgenda: Metric;
  miscommunication: Metric;
  inLove: Metric;
  flirting: Metric;
  shy: Metric;
  summary: string;
};

type ScreenshotUploadProps = {
  onResult: (result: AnalysisResult) => void;
  onError: (message: string) => void;
  canAnalyze: () => boolean;
};

const ScreenshotUpload: React.FC<ScreenshotUploadProps> = ({
  onResult,
  onError,
  canAnalyze,
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);

  const apiBase =
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = e.target.files?.[0];
    if (!selected) return;

    if (!selected.type.startsWith("image/")) {
      const msg = "Please select a PNG or JPEG screenshot.";
      setLocalError(msg);
      onError(msg);
      setFile(null);
      setPreviewUrl(null);
      return;
    }

    setFile(selected);
    setLocalError(null);
    const url = URL.createObjectURL(selected);
    setPreviewUrl(url);
  };

  const handleUpload = async () => {
    if (!file) {
      const msg = "Choose a screenshot first.";
      setLocalError(msg);
      onError(msg);
      return;
    }

    // Free vs Pro gating
    if (!canAnalyze()) {
      return;
    }

    setIsUploading(true);
    setLocalError(null);
    onError("");

    try {
      const formData = new FormData();
      formData.append("image", file);

      const res = await fetch(`${apiBase}/analyze-image`, {
        method: "POST",
        body: formData,
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(
          body || `Screenshot analysis failed with ${res.status}`
        );
      }

      const data = (await res.json()) as AnalysisResult;
      onResult(data);
    } catch (err: unknown) {
      const message =
        err instanceof Error
          ? err.message
          : "Unexpected screenshot analysis error.";
      setLocalError(message);
      onError(message);
      console.error(err);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="mt-4 space-y-2 rounded-2xl border border-slate-700 bg-slate-950/60 p-3">
      <div className="flex items-center justify-between gap-2">
        <span className="text-xs font-semibold text-slate-200">
          Or upload a screenshot
        </span>
        <button
          type="button"
          onClick={handleUpload}
          disabled={isUploading || !file}
          className="inline-flex items-center justify-center rounded-lg bg-fuchsia-500 px-3 py-1.5 text-[11px] font-semibold text-slate-950 shadow-md shadow-fuchsia-900/40 transition hover:bg-fuchsia-400 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isUploading ? "Analyzing..." : "Analyze Screenshot"}
        </button>
      </div>

      <label className="flex cursor-pointer flex-col items-center justify-center rounded-xl border border-dashed border-slate-600 bg-slate-900/60 px-3 py-4 text-center text-[11px] text-slate-400 hover:border-fuchsia-500/70 hover:text-fuchsia-300">
        <input
          type="file"
          accept="image/png,image/jpeg"
          className="hidden"
          onChange={handleFileChange}
        />
        <span className="font-medium">
          Click to choose a PNG or JPEG conversation screenshot
        </span>
        <span className="mt-1 text-[10px] text-slate-500">
          We only use it to analyze this compatibility. Nothing is stored.
        </span>
      </label>

      {previewUrl && (
        <div className="overflow-hidden rounded-xl border border-slate-700 bg-slate-900/70">
          <img
            src={previewUrl}
            alt="Conversation preview"
            className="max-h-64 w-full object-cover"
          />
        </div>
      )}

      {localError && (
        <p className="text-[11px] text-red-400">{localError}</p>
      )}
    </div>
  );
};

export default ScreenshotUpload;
'@

Set-Content -Path $screenshotPath -Value $screenshotContent -Encoding UTF8
Write-Host "ScreenshotUpload.tsx written." -ForegroundColor Green

# -------------------------------------------------------------------
# frontend/src/App.tsx (compatibility + chat + paywall)
# -------------------------------------------------------------------
Write-Host "Writing App.tsx to: $appPath" -ForegroundColor Yellow

$appContent = @'
import React, { useEffect, useState } from "react";
import ScreenshotUpload from "./components/ScreenshotUpload";
import BrandWatermark from "./components/BrandWatermark";
import VibeGauge, { CompatibilityMode } from "./components/VibeGauge";
import ConversationPreview from "./components/ConversationPreview";

type Metric = {
  score: number | string;
  reason: string;
};

type AnalysisResult = {
  honesty?: Metric;
  gaslighting?: Metric;
  hiddenAgenda?: Metric;
  miscommunication?: Metric;
  inLove?: Metric;
  flirting?: Metric;
  shy?: Metric;
  summary: string;
};

const FREE_DAILY_LIMIT = 5;
const USAGE_KEY = "confusionai_usage_v1";
const PRO_KEY = "confusionai_isPro_v1";

const toScore = (metric?: Metric): number | null => {
  if (!metric) return null;
  const n = Number(metric.score);
  if (!Number.isFinite(n)) return null;
  return Math.max(0, Math.min(100, n));
};

const average = (values: (number | null | undefined)[]): number | null => {
  const nums = values.filter(
    (v): v is number => typeof v === "number" && Number.isFinite(v)
  );
  if (nums.length === 0) return null;
  const sum = nums.reduce((acc, v) => acc + v, 0);
  return sum / nums.length;
};

const deriveCompatibility = (
  result: AnalysisResult | null
): { mode: CompatibilityMode; overall: number | null } => {
  if (!result) {
    return { mode: "mixed", overall: null };
  }

  const honesty = toScore(result.honesty);
  const gaslighting = toScore(result.gaslighting);
  const hidden = toScore(result.hiddenAgenda);
  const miscommunication = toScore(result.miscommunication);
  const inLove = toScore(result.inLove);
  const flirting = toScore(result.flirting);

  const negativity = average([gaslighting, hidden, miscommunication]); // how toxic
  const romance = average([inLove, flirting]); // how in love
  const honestyScore = honesty;

  let mode: CompatibilityMode = "mixed";

  if (romance !== null && romance >= 60 && (negativity ?? 0) <= 65) {
    mode = "in_love";
  } else if (negativity !== null && negativity >= 60 && (honestyScore ?? 50) <= 50) {
    mode = "toxic";
  } else if (honestyScore !== null && honestyScore >= 60 && (negativity ?? 0) <= 45) {
    mode = "honest";
  }

  let overall: number | null = null;

  if (mode === "toxic" && negativity !== null) {
    overall = 100 - negativity; // higher toxicity -> lower compatibility
  } else if (mode === "in_love" && romance !== null) {
    overall = romance;
  } else if (mode === "honest" && honestyScore !== null) {
    overall = honestyScore;
  } else {
    overall = average([
      honesty,
      romance,
      negativity !== null ? 100 - negativity : null,
    ]);
  }

  if (overall === null || !Number.isFinite(overall)) {
    return { mode, overall: null };
  }

  return {
    mode,
    overall: Math.max(0, Math.min(100, overall)),
  };
};

const compatibilityTheme: Record<
  CompatibilityMode,
  { base: string; glow: string; accentPill: string }
> = {
  mixed: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(148,163,184,0.35),_rgba(15,23,42,0.98))]",
    accentPill: "text-slate-200 border-slate-400",
  },
  honest: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(34,197,94,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-emerald-300 border-emerald-500/60",
  },
  toxic: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(248,113,113,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-red-300 border-red-500/60",
  },
  in_love: {
    base: "bg-slate-950",
    glow:
      "bg-[radial-gradient(circle_at_top,_rgba(59,130,246,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-sky-300 border-sky-500/60",
  },
};

const App: React.FC = () => {
  const [text, setText] = useState("");
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const [isPro, setIsPro] = useState(false);
  const [usageDate, setUsageDate] = useState<string | null>(null);
  const [dailyCount, setDailyCount] = useState(0);
  const [isCreatingCheckout, setIsCreatingCheckout] = useState(false);

  const apiBase =
    import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  const { mode, overall } = deriveCompatibility(result);
  const theme = compatibilityTheme[mode];

  // Initialize usage & Pro flag from localStorage + URL
  useEffect(() => {
    const today = new Date().toISOString().slice(0, 10);

    try {
      const storedUsage = localStorage.getItem(USAGE_KEY);
      if (storedUsage) {
        const parsed = JSON.parse(storedUsage) as { date?: string; count?: number };
        if (parsed.date === today && typeof parsed.count === "number") {
          setUsageDate(parsed.date);
          setDailyCount(parsed.count);
        } else {
          const fresh = { date: today, count: 0 };
          localStorage.setItem(USAGE_KEY, JSON.stringify(fresh));
          setUsageDate(today);
          setDailyCount(0);
        }
      } else {
        const fresh = { date: today, count: 0 };
        localStorage.setItem(USAGE_KEY, JSON.stringify(fresh));
        setUsageDate(today);
        setDailyCount(0);
      }
    } catch (e) {
      console.error("Failed to initialize usage from localStorage", e);
    }

    try {
      const storedPro = localStorage.getItem(PRO_KEY);
      if (storedPro === "true") {
        setIsPro(true);
      }

      const params = new URLSearchParams(window.location.search);
      if (params.get("plan") === "pro") {
        setIsPro(true);
        localStorage.setItem(PRO_KEY, "true");
        params.delete("plan");
        const newQuery = params.toString();
        const newUrl =
          window.location.pathname +
          (newQuery ? "?" + newQuery : "") +
          window.location.hash;
        window.history.replaceState(null, "", newUrl);
      }
    } catch (e) {
      console.error("Failed to initialize Pro flag", e);
    }
  }, []);

  const recordAnalysis = () => {
    const today = new Date().toISOString().slice(0, 10);
    setUsageDate(today);
    setDailyCount((prev) => {
      const next = prev + 1;
      try {
        localStorage.setItem(
          USAGE_KEY,
          JSON.stringify({ date: today, count: next })
        );
      } catch (e) {
        console.error("Failed to persist usage", e);
      }
      return next;
    });
  };

  const canRunAnotherAnalysis = () => {
    if (isPro) return true;
    if (dailyCount >= FREE_DAILY_LIMIT) {
      setError(
        `Free plan: ${FREE_DAILY_LIMIT} analyses per day. Upgrade to Pro for unlimited compatibility checks.`
      );
      return false;
    }
    return true;
  };

  const handleAnalyzeText = async () => {
    if (!text.trim()) {
      setError("Paste a conversation first.");
      return;
    }

    if (!canRunAnotherAnalysis()) {
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const res = await fetch(`${apiBase}/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ text }),
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Text analysis failed with ${res.status}`);
      }

      const data = (await res.json()) as AnalysisResult;
      setResult(data);
      recordAnalysis();
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Unexpected analysis error.";
      setError(message);
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpgradeClick = async () => {
    try {
      setError(null);
      setIsCreatingCheckout(true);

      const res = await fetch(`${apiBase}/create-checkout-session`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Upgrade failed (${res.status})`);
      }

      const data = (await res.json()) as { url?: string };
      if (data.url) {
        window.location.href = data.url;
        return;
      }
      throw new Error("No checkout URL returned.");
    } catch (err: unknown) {
      const message =
        err instanceof Error
          ? err.message
          : "Upgrade failed. Please try again later.";
      setError(message);
      console.error(err);
    } finally {
      setIsCreatingCheckout(false);
    }
  };

  const renderMetric = (label: string, metric?: Metric) => {
    if (!metric) return null;

    const n = toScore(metric);
    if (n === null) return null;

    return (
      <div className="rounded-xl border border-slate-700 bg-slate-900/60 p-3">
        <div className="flex items-center justify-between text-sm font-semibold text-slate-100">
          <span>{label}</span>
          <span className="text-emerald-400">
            {n.toFixed(0)}/100
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-300">{metric.reason}</p>
      </div>
    );
  };

  const compatibilityPillLabel =
    mode === "honest"
      ? "Compatibility: Honest"
      : mode === "toxic"
      ? "Compatibility: Toxic"
      : mode === "in_love"
      ? "Compatibility: In Love"
      : "Compatibility: Mixed";

  return (
    <div
      className={`relative min-h-screen text-slate-50 transition-colors duration-700 ${theme.base}`}
    >
      <div
        className={`pointer-events-none absolute inset-0 -z-10 opacity-70 blur-3xl ${theme.glow}`}
      />
      <div className="relative z-10">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-6">
          <header className="flex flex-col gap-3 sm:flex-row sm:items-baseline sm:justify-between">
            <div>
              <h1 className="bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-500 bg-clip-text text-3xl font-bold tracking-tight text-transparent">
                Confusion-AI
              </h1>
              <p className="text-xs text-slate-400">
                Drop in your chat or a screenshot. I&apos;ll read the compatibility:
                honesty, gaslighting, hidden agenda, miscommunication, in love,
                flirting, and shy.
              </p>
              <div className="mt-2 text-[10px] text-slate-400">
                {isPro ? (
                  <span>Pro: unlimited daily analyses.</span>
                ) : (
                  <span>
                    Free: {dailyCount}/{FREE_DAILY_LIMIT} analyses today.
                  </span>
                )}
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full border border-emerald-500/40 bg-emerald-500/10 px-3 py-1 text-[10px] font-medium uppercase tracking-wide text-emerald-300">
                Innovative Solutions
              </span>
              <span
                className={`rounded-full border bg-slate-900/70 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${theme.accentPill}`}
              >
                {compatibilityPillLabel}
              </span>
              <button
                type="button"
                onClick={handleUpgradeClick}
                disabled={isPro || isCreatingCheckout}
                className="inline-flex items-center justify-center rounded-full bg-fuchsia-500 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-950 shadow-md shadow-fuchsia-900/40 transition hover:bg-fuchsia-400 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isPro
                  ? "Pro active"
                  : isCreatingCheckout
                  ? "Redirecting..."
                  : "Upgrade to Pro"}
              </button>
            </div>
          </header>

          <main className="grid gap-4 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            {/* LEFT: input + chat preview + screenshot */}
            <section className="flex flex-col gap-3">
              <label className="text-xs font-semibold text-slate-200">
                Paste conversation
              </label>
              <textarea
                className="min-h-[160px] w-full rounded-2xl border border-slate-700 bg-slate-950/70 p-3 text-sm text-slate-100 outline-none ring-emerald-500/40 placeholder:text-slate-500 focus:ring-2"
                placeholder="Paste text messages, DMs, or chat logs here..."
                value={text}
                onChange={(e) => setText(e.target.value)}
              />

              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={handleAnalyzeText}
                  disabled={isLoading}
                  className="inline-flex items-center justify-center rounded-xl bg-emerald-500 px-4 py-2 text-xs font-semibold text-slate-950 shadow-lg shadow-emerald-900/40 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isLoading ? "Analyzing..." : "Analyze Text"}
                </button>
                {error && (
                  <span className="text-xs text-red-400 max-w-xs">
                    {error}
                  </span>
                )}
              </div>

              <ConversationPreview rawText={text} />

              <ScreenshotUpload
                canAnalyze={canRunAnotherAnalysis}
                onResult={(data) => {
                  setResult(data as AnalysisResult);
                  setError(null);
                  recordAnalysis();
                }}
                onError={(message) => {
                  setError(message || null);
                }}
              />
            </section>

            {/* RIGHT: gauge + results */}
            <section className="flex flex-col gap-3">
              <VibeGauge score={overall} mode={mode} />

              <h2 className="text-sm font-semibold text-slate-100">
                Compatibility breakdown
              </h2>
              {!result && (
                <p className="text-xs text-slate-400">
                  Run an analysis to see compatibility and detailed metrics here.
                </p>
              )}

              {result && (
                <>
                  <div className="rounded-2xl border border-slate-700 bg-slate-900/80 p-3">
                    <p className="text-xs text-slate-300">{result.summary}</p>
                  </div>
                  <div className="grid grid-cols-1 gap-2 text-xs">
                    {renderMetric("Honesty", result.honesty)}
                    {renderMetric("Gaslighting", result.gaslighting)}
                    {renderMetric("Hidden agenda", result.hiddenAgenda)}
                    {renderMetric(
                      "Miscommunication",
                      result.miscommunication
                    )}
                    {renderMetric("In love", result.inLove)}
                    {renderMetric("Flirting", result.flirting)}
                    {renderMetric("Shy", result.shy)}
                  </div>
                </>
              )}
            </section>
          </main>
        </div>
        <BrandWatermark />
      </div>
    </div>
  );
};

export default App;
'@

Set-Content -Path $appPath -Value $appContent -Encoding UTF8
Write-Host "App.tsx written." -ForegroundColor Green

Write-Host "=== Confusion-AI: Monetization + Chat UI Phase 1 complete. ===" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "  1) cd `"$backendPath`""
Write-Host "     - Create/adjust .env with STRIPE_SECRET_KEY, STRIPE_PRICE_ID, APP_BASE_URL"
Write-Host "     - npm run dev"
Write-Host "  2) cd `"$frontendPath`""
Write-Host "     - npm run dev"
