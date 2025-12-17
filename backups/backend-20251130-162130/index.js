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
