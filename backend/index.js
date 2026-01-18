'use strict';

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const morgan = require('morgan');
require('dotenv').config();

const { OpenAI } = require('openai');

const PORT = Number(process.env.PORT || 4000);
const OPENAI_MODEL_TEXT = process.env.OPENAI_MODEL_TEXT || 'gpt-4o-mini';
const OPENAI_MODEL_VISION = process.env.OPENAI_MODEL_VISION || 'gpt-4o-mini';

if (!process.env.OPENAI_API_KEY) {
  console.warn('[WARN] OPENAI_API_KEY is missing. Analyze endpoints will fail.');
}

const app = express();

/* =========================================================
   CORS CONFIG — Vercel + Local + Previews
   ========================================================= */

const explicitAllowList = [
  'https://confusion-ai.vercel.app',
  'http://localhost:5173',
  'http://localhost:5174',
];

function isAllowedOrigin(origin) {
  if (!origin) return true; // curl, server-to-server
  if (explicitAllowList.includes(origin)) return true;

  // Allow all Vercel preview deployments
  if (/^https:\/\/.*\.vercel\.app$/i.test(origin)) return true;

  return false;
}

const corsOptions = {
  origin: (origin, cb) => {
    if (isAllowedOrigin(origin)) return cb(null, true);
    return cb(new Error('CORS blocked for origin: ' + origin));
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: false,
  maxAge: 86400,
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

/* ========================================================= */

app.disable('x-powered-by');
app.use(morgan('tiny'));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

/* =========================================================
   MULTER (in-memory)
   ========================================================= */

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024 }, // 12MB
});

/* =========================================================
   OPENAI CLIENT
   ========================================================= */

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/* =========================================================
   HELPERS
   ========================================================= */

function clampScore(n) {
  const x = Number(n);
  if (!Number.isFinite(x)) return 0;
  return Math.max(0, Math.min(100, x));
}

function normalizeMetric(m) {
  if (!m || typeof m !== 'object') {
    return { score: 0, reason: '' };
  }
  return {
    score: clampScore(m.score),
    reason: String(m.reason || ''),
  };
}

function normalizeAnalysis(a = {}) {
  return {
    honesty: normalizeMetric(a.honesty),
    gaslighting: normalizeMetric(a.gaslighting),
    hiddenAgenda: normalizeMetric(a.hiddenAgenda),
    miscommunication: normalizeMetric(a.miscommunication),
    inLove: normalizeMetric(a.inLove),
    flirting: normalizeMetric(a.flirting),
    shy: normalizeMetric(a.shy),
    summary: String(a.summary || ''),
    extractedText: a.extractedText ? String(a.extractedText) : undefined,
    messages: Array.isArray(a.messages)
      ? a.messages.map(m => ({
        sender: String(m.sender || 'Unknown'),
        text: String(m.text || ''),
      }))
      : undefined,
  };
}

/* =========================================================
   TEXT ANALYSIS
   ========================================================= */

async function runTextAnalysis(text) {
  const systemPrompt = `
You are Confusion-AI by Innovative Solutions.
Analyze the conversation and return ONLY strict JSON.

Schema:
{
  "honesty":{"score":0-100,"reason":"..."},
  "gaslighting":{"score":0-100,"reason":"..."},
  "hiddenAgenda":{"score":0-100,"reason":"..."},
  "miscommunication":{"score":0-100,"reason":"..."},
  "inLove":{"score":0-100,"reason":"..."},
  "flirting":{"score":0-100,"reason":"..."},
  "shy":{"score":0-100,"reason":"..."},
  "summary":"1-3 sentences"
}

No markdown. No extra keys.
`;

  const resp = await openai.chat.completions.create({
    model: OPENAI_MODEL_TEXT,
    temperature: 0.4,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: `Conversation:\n${text}` },
    ],
  });

  const content = resp.choices?.[0]?.message?.content || '{}';
  return normalizeAnalysis(JSON.parse(content));
}

/* =========================================================
   IMAGE ANALYSIS
   ========================================================= */

async function runImageAnalysis(imageBuffer, mimeType) {
  const dataUrl = `data:${mimeType};base64,${imageBuffer.toString('base64')}`;

  const systemPrompt = `
You are Confusion-AI by Innovative Solutions.
Read a screenshot of a conversation and return ONLY strict JSON.

Include:
- extractedText
- messages [{sender,text}]
- all scoring metrics
- summary

No markdown. No extra keys.
`;

  const resp = await openai.chat.completions.create({
    model: OPENAI_MODEL_VISION,
    temperature: 0.2,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: systemPrompt },
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Analyze this screenshot.' },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      },
    ],
  });

  const content = resp.choices?.[0]?.message?.content || '{}';
  return normalizeAnalysis(JSON.parse(content));
}

/* =========================================================
   ROUTES
   ========================================================= */

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'confusion-ai-backend',
    time: new Date().toISOString(),
  });
});

app.post('/analyze', async (req, res) => {
  try {
    const text = String(req.body?.text || '').trim();
    if (!text) return res.status(400).json({ error: 'Missing text' });

    const result = await runTextAnalysis(text);
    res.json(result);
  } catch (err) {
    console.error('Analyze error:', err);
    res.status(500).json({ error: 'Failed to analyze text' });
  }
});

app.post('/analyze-image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Missing image file' });
    }

    const result = await runImageAnalysis(
      req.file.buffer,
      req.file.mimetype || 'image/png'
    );

    res.json(result);
  } catch (err) {
    console.error('Image analyze error:', err);
    res.status(500).json({ error: 'Failed to analyze image' });
  }
});

/* ========================================================= */

app.listen(PORT, () => {
  console.log(`Confusion-AI backend listening on port ${PORT}`);
});
