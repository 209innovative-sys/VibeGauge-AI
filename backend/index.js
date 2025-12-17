require("dotenv").config();
const express = require("express");
const cors = require("cors");
const multer = require("multer");
const axios = require("axios");
const Stripe = require("stripe");

const app = express();

// ----- Config -----
const PORT = process.env.PORT || 4000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_TEXT_MODEL = process.env.OPENAI_TEXT_MODEL || "gpt-4o-mini";
const OPENAI_IMAGE_MODEL = process.env.OPENAI_IMAGE_MODEL || OPENAI_TEXT_MODEL;
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const STRIPE_PRICE_ID = process.env.STRIPE_PRICE_ID;
const APP_BASE_URL = process.env.APP_BASE_URL || "http://localhost:5173";

if (!OPENAI_API_KEY) {
  console.warn("⚠️  OPENAI_API_KEY is not set. /analyze and /analyze-image will fail.");
}

let stripe = null;
if (!STRIPE_SECRET_KEY) {
  console.warn("⚠️  STRIPE_SECRET_KEY is not set. /create-checkout-session will be disabled.");
} else {
  stripe = new Stripe(STRIPE_SECRET_KEY);
}

// ----- Middleware -----
const allowedOrigins = (process.env.CORS_ORIGIN || "http://localhost:5173")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.indexOf(origin) !== -1) {
        return callback(null, true);
      }
      console.warn("🚫 CORS blocked origin:", origin);
      return callback(new Error("Not allowed by CORS"));
    },
    credentials: true,
  })
);

app.use(express.json({ limit: "5mb" }));

// Multer for image uploads (memory storage)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

// ----- Helper: call OpenAI -----
async function callOpenAIForAnalysis({ text, imageBase64, isImage }) {
  if (!OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY not configured");
  }

  const model = isImage ? OPENAI_IMAGE_MODEL : OPENAI_TEXT_MODEL;

  const systemPrompt = `
You are Confusion-AI, a conversation vibe and compatibility analyzer.

You MUST respond ONLY with a strict JSON object matching this TypeScript type:

type CompatibilityMode = "honest" | "toxic" | "in_love" | "mixed";

interface ConfusionAIMetrics {
  honesty: number;          // 0-100, higher = more honest
  gaslighting: number;      // 0-100, higher = more gaslighting
  hiddenAgenda: number;     // 0-100, higher = more hidden motives
  miscommunication: number; // 0-100, higher = more miscommunication
  inLove: number;           // 0-100, perceived romantic love level
  flirting: number;         // 0-100, perceived flirting
  shy: number;              // 0-100, perceived shyness or nervousness
  overallCompatibility: number;  // 0-100, higher = better compatibility
  compatibilityLabel: string;    // short text label, e.g. "Healthy & honest", "Toxic & manipulative"
  mode: CompatibilityMode;       // used to control the gauge background
  summary: string;               // 2-4 sentences summarizing the dynamic
}

Rules:
- Numbers MUST be integers between 0 and 100.
- "mode" should be:
  - "honest" if honesty is high and gaslighting is low.
  - "toxic" if gaslighting or hiddenAgenda are high.
  - "in_love" if inLove is high and overallCompatibility is high.
  - "mixed" if the signals are conflicting.
- Do NOT include any markdown, backticks, explanations, or extra keys.
Only output the JSON object, nothing else.
`.trim();

  const userPromptText = isImage
    ? "Analyze the emotional dynamics and compatibility of the conversation, using both the image and any text you can read."
    : "Analyze the emotional dynamics and compatibility of the following conversation text.";

  const messages = [
    { role: "system", content: systemPrompt },
    {
      role: "user",
      content: isImage
        ? [
            { type: "text", text: userPromptText },
            {
              type: "image_url",
              image_url: {
                url: `data:image/png;base64,${imageBase64}`,
              },
            },
          ]
        : userPromptText + "\n\n" + text,
    },
  ];

  const response = await axios.post(
    "https://api.openai.com/v1/chat/completions",
    {
      model,
      messages,
      temperature: 0.4,
      response_format: { type: "json_object" },
    },
    {
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      timeout: 30000,
    }
  );

  const content = response.data.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("No content returned from OpenAI");
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    console.error("❌ Failed to parse OpenAI JSON:", err);
    throw new Error("Failed to parse AI response");
  }

  return parsed;
}

// ----- Routes -----

// Health check
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

// Text analysis
app.post("/analyze", async (req, res) => {
  try {
    const { text } = req.body || {};
    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return res.status(400).json({ error: "Missing 'text' field in body." });
    }

    const metrics = await callOpenAIForAnalysis({
      text: text.trim(),
      isImage: false,
    });

    return res.json(metrics);
  } catch (err) {
    console.error("❌ /analyze error:", err.response?.data || err.message || err);
    return res.status(500).json({ error: "Failed to analyze conversation." });
  }
});

// Image (screenshot) analysis
app.post("/analyze-image", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res
        .status(400)
        .json({ error: "No image uploaded. Use field name 'image'." });
    }

    const buffer = req.file.buffer;
    const base64 = buffer.toString("base64");

    const metrics = await callOpenAIForAnalysis({
      text: "",
      imageBase64: base64,
      isImage: true,
    });

    return res.json(metrics);
  } catch (err) {
    console.error(
      "❌ /analyze-image error:",
      err.response?.data || err.message || err
    );
    return res.status(500).json({ error: "Failed to analyze screenshot." });
  }
});

// Stripe Checkout for Pro upgrade
app.post("/create-checkout-session", async (req, res) => {
  try {
    if (!stripe || !STRIPE_PRICE_ID) {
      return res
        .status(500)
        .json({ error: "Stripe not configured on server." });
    }

    const successUrl = `${APP_BASE_URL.replace(/\/$/, "")}/?plan=pro&session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = `${APP_BASE_URL.replace(/\/$/, "")}/?plan=free&canceled=1`;

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [
        {
          price: STRIPE_PRICE_ID,
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
    });

    return res.json({ url: session.url });
  } catch (err) {
    console.error("❌ /create-checkout-session error:", err);
    return res
      .status(500)
      .json({ error: "Failed to create Stripe Checkout session." });
  }
});

// ----- Start server -----
app.listen(PORT, () => {
  console.log(`✅ Confusion-AI backend listening on port ${PORT}`);
});
