$root = "C:\Users\Alexi\Desktop\VibeGauge-AI"

function Write-FileWithBackup {
    param(
        [string] $RelativePath,
        [string] $Content
    )

    $fullPath = Join-Path $root $RelativePath
    $dir = Split-Path $fullPath -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path $fullPath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$fullPath.bak-$timestamp"
        Copy-Item $fullPath $backupPath -Force
        Write-Host "Backup created: $backupPath"
    }

    $Content | Set-Content -Path $fullPath -Encoding UTF8
    Write-Host "Wrote: $RelativePath"
}

# ================================
# api-contracts/analyze.json.md
# ================================
$apiContract = @"
# Confusion-AI `/analyze` API Contract (v1)

## Endpoint

- Method: POST
- URL: https://confusion-ai.onrender.com/analyze
- Content-Type: application/json

## Request Body

{
  "text": "string - required, conversation text to analyze",
  "metadata": {
    "source": "string - optional, e.g. 'web', 'android', 'ios'",
    "language": "string - optional, e.g. 'en'",
    "clientVersion": "string - optional, e.g. '1.0.0'"
  }
}

## Success Response

{
  "ok": true,
  "analysis": {
    "summary": "short summary of the vibe",
    "overallScore": 0,
    "metrics": {
      "honesty": 0,
      "gaslighting": 0,
      "hiddenAgenda": 0,
      "miscommunication": 0,
      "inLove": 0,
      "flirting": 0,
      "shy": 0
    },
    "notes": ["short bullet-style notes"]
  },
  "requestId": "string id",
  "timestamp": "ISO-8601 UTC string"
}

## Error Response

{
  "ok": false,
  "error": {
    "code": "VALIDATION_ERROR | INTERNAL_ERROR | ...",
    "message": "human readable error message",
    "details": null
  },
  "requestId": "string id",
  "timestamp": "ISO-8601 UTC string"
}
"@

# ================================
# Frontend env files
# ================================
$envDev = @"
VITE_API_BASE_URL=http://localhost:4000
"@

$envProd = @"
VITE_API_BASE_URL=https://confusion-ai.onrender.com
"@

# ================================
# Backend .env
# ================================
$serverEnv = @"
PORT=4000
NODE_ENV=development
"@

# ================================
# frontend/src/types/analyze.ts
# ================================
$frontendTypes = @"
export interface AnalyzeRequestMetadata {
  source?: 'web' | 'android' | 'ios' | string;
  language?: string;
  clientVersion?: string;
}

export interface AnalyzeRequestBody {
  text: string;
  metadata?: AnalyzeRequestMetadata;
}

export interface AnalyzeMetrics {
  honesty: number;        // 0–100
  gaslighting: number;    // 0–100
  hiddenAgenda: number;   // 0–100
  miscommunication: number; // 0–100
  inLove: number;         // 0–100
  flirting: number;       // 0–100
  shy: number;            // 0–100
}

export interface AnalyzeResult {
  summary: string;
  overallScore: number; // 0–100
  metrics: AnalyzeMetrics;
  notes: string[];
}

export interface AnalyzeSuccessResponse {
  ok: true;
  analysis: AnalyzeResult;
  requestId: string;
  timestamp: string;
}

export interface AnalyzeErrorInfo {
  code: string;
  message: string;
  details?: unknown;
}

export interface AnalyzeErrorResponse {
  ok: false;
  error: AnalyzeErrorInfo;
  requestId: string;
  timestamp: string;
}

export type AnalyzeApiResponse = AnalyzeSuccessResponse | AnalyzeErrorResponse;
"@

# ================================
# frontend/src/config/api.ts
# ================================
$frontendApi = @"
import type {
  AnalyzeRequestBody,
  AnalyzeApiResponse,
  AnalyzeSuccessResponse,
} from '../types/analyze';

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || 'https://confusion-ai.onrender.com';

export function getApiBaseUrl(): string {
  return API_BASE_URL.endsWith('/') ? API_BASE_URL.slice(0, -1) : API_BASE_URL;
}

export async function analyzeConversation(
  text: string,
  options?: { source?: string; language?: string; clientVersion?: string }
): Promise<AnalyzeSuccessResponse> {
  const baseUrl = getApiBaseUrl();

  const body: AnalyzeRequestBody = {
    text,
    metadata: {
      source: options?.source ?? 'web',
      language: options?.language ?? 'en',
      clientVersion: options?.clientVersion ?? '1.0.0',
    },
  };

  const response = await fetch(baseUrl + '/analyze', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = (await response.json()) as AnalyzeApiResponse;

  if (!response.ok || !data.ok) {
    const errorMessage =
      !data.ok && data.error
        ? data.error.message
        : 'Request failed with status ' + response.status;
    throw new Error(errorMessage);
  }

  return data;
}
"@

# ================================
# frontend/src/App.tsx
# ================================
$frontendApp = @"
import React, { useState } from 'react';
import { analyzeConversation } from './config/api';
import type { AnalyzeSuccessResponse } from './types/analyze';

const METRIC_LABELS: { key: keyof AnalyzeSuccessResponse['analysis']['metrics']; label: string }[] =
  [
    { key: 'honesty', label: 'Honesty' },
    { key: 'gaslighting', label: 'Gaslighting' },
    { key: 'hiddenAgenda', label: 'Hidden Agenda' },
    { key: 'miscommunication', label: 'Miscommunication' },
    { key: 'inLove', label: 'In Love' },
    { key: 'flirting', label: 'Flirting' },
    { key: 'shy', label: 'Shy' },
  ];

function MetricBar({
  label,
  value,
}: {
  label: string;
  value: number;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs text-slate-300">
        <span>{label}</span>
        <span>{value}</span>
      </div>
      <div className="h-2 w-full rounded-full bg-slate-800">
        <div
          className="h-2 rounded-full bg-gradient-to-r from-cyan-400 via-purple-500 to-pink-500 transition-all duration-500"
          style={{ width: value + '%' }}
        />
      </div>
    </div>
  );
}

const App: React.FC = () => {
  const [text, setText] = useState('');
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<AnalyzeSuccessResponse | null>(null);

  const handleAnalyze = async () => {
    setError(null);
    setResult(null);

    const trimmed = text.trim();
    if (!trimmed) {
      setError('Please paste or type a conversation first.');
      return;
    }

    setIsAnalyzing(true);
    try {
      const res = await analyzeConversation(trimmed, {
        source: 'web',
        clientVersion: '1.0.0',
      });
      setResult(res);
    } catch (err: any) {
      console.error('Analyze error:', err);
      setError(err?.message ?? 'Something went wrong while analyzing.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 text-slate-100 flex flex-col">
      <header className="px-4 py-3 border-b border-slate-800 flex items-center justify-between">
        <div>
          <h1 className="text-lg font-semibold tracking-tight">
            Confusion-AI
          </h1>
          <p className="text-xs text-slate-400">
            Decode the vibe in any conversation.
          </p>
        </div>
        <span className="rounded-full bg-slate-900/70 px-3 py-1 text-[10px] uppercase tracking-wide text-slate-400 border border-slate-700">
          v1 • Beta
        </span>
      </header>

      <main className="flex-1 px-4 py-4 flex flex-col gap-4 max-w-xl w-full mx-auto">
        <section className="space-y-2">
          <label className="text-xs font-medium text-slate-300">
            Paste or type your conversation
          </label>
          <textarea
            className="w-full min-h-[160px] rounded-2xl bg-slate-950/70 border border-slate-800 px-3 py-2 text-sm resize-vertical focus:outline-none focus:ring-2 focus:ring-purple-500/70 focus:border-purple-500/70 placeholder:text-slate-500"
            placeholder="Paste messages here and tap Analyze to see the vibe…"
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <p className="text-[10px] text-slate-500">
            Your text is sent securely to our server for analysis. We don&apos;t
            create accounts or store your conversations for this v1. For
            insight and entertainment only.
          </p>
        </section>

        <button
          type="button"
          onClick={handleAnalyze}
          disabled={isAnalyzing}
          className="inline-flex items-center justify-center rounded-2xl bg-gradient-to-r from-cyan-500 via-purple-500 to-pink-500 px-4 py-2 text-sm font-semibold shadow-lg shadow-purple-500/30 disabled:opacity-60 disabled:cursor-not-allowed"
        >
          {isAnalyzing ? 'Analyzing…' : 'Analyze vibe'}
        </button>

        {error && (
          <div className="rounded-xl border border-red-500/50 bg-red-950/40 px-3 py-2 text-xs text-red-100">
            {error}
          </div>
        )}

        {result && (
          <section className="space-y-3">
            <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3 space-y-2">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-slate-400">Overall Vibe</p>
                  <p className="text-sm font-semibold">
                    {result.analysis.summary}
                  </p>
                </div>
                <div className="flex flex-col items-end">
                  <div className="relative flex items-center justify-center w-12 h-12 rounded-full bg-slate-900 border border-slate-700">
                    <span className="text-xs font-bold">
                      {result.analysis.overallScore}
                    </span>
                  </div>
                  <span className="text-[10px] text-slate-500 mt-1">
                    Score / 100
                  </span>
                </div>
              </div>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3 space-y-3">
              <p className="text-xs text-slate-300 font-medium">
                Metrics
              </p>
              <div className="space-y-2">
                {METRIC_LABELS.map((m) => (
                  <MetricBar
                    key={m.key}
                    label={m.label}
                    value={result.analysis.metrics[m.key]}
                  />
                ))}
              </div>
            </div>

            {result.analysis.notes.length > 0 && (
              <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3 space-y-2">
                <p className="text-xs text-slate-300 font-medium">Notes</p>
                <ul className="space-y-1 text-xs text-slate-300">
                  {result.analysis.notes.map((note, idx) => (
                    <li key={idx} className="flex gap-2">
                      <span className="mt-[2px] h-[6px] w-[6px] rounded-full bg-purple-500" />
                      <span>{note}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </section>
        )}
      </main>
    </div>
  );
};

export default App;
"@

# ================================
# server/analyzeLogic.js
# ================================
$analyzeLogic = @"
function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function keywordCount(text, keywords) {
  const lower = text.toLowerCase();
  let count = 0;
  for (const kw of keywords) {
    const regex = new RegExp('\\b' + kw + '\\b', 'gi');
    const matches = lower.match(regex);
    if (matches) count += matches.length;
  }
  return count;
}

function analyzeTextToMetrics(text) {
  const lower = text.toLowerCase();
  const lengthScore = clamp(Math.log10(text.length + 1) * 20, 0, 100);

  const honestyBoost = keywordCount(lower, [
    'honest',
    'truth',
    'truly',
    'swear',
    'i promise',
  ]);

  const gaslightSignals = keywordCount(lower, [
    'you are crazy',
    "you're crazy",
    'you imagine',
    'that never happened',
    'you always',
    'you never',
    'overreacting',
  ]);

  const hiddenAgendaSignals = keywordCount(lower, [
    'deal',
    'favor',
    'if you',
    'in return',
    "don't tell",
    'secret',
  ]);

  const miscommunicationSignals = keywordCount(lower, [
    'misunderstand',
    'not what i said',
    "that's not what",
    'i meant',
    'confused',
    'clarify',
  ]);

  const loveSignals = keywordCount(lower, [
    'love you',
    'in love',
    'i love',
    'miss you',
    'baby',
    'babe',
    'my love',
    'darling',
  ]);

  const flirtSignals = keywordCount(lower, [
    'cute',
    'beautiful',
    'handsome',
    'hot',
    'kiss',
    'date',
    'go out',
    '😍',
    '😉',
    '😘',
  ]);

  const shySignals = keywordCount(lower, [
    'idk',
    'maybe',
    'i guess',
    'not sure',
    'sorry',
    'nervous',
    'awkward',
  ]);

  const metrics = {
    honesty: clamp(50 + honestyBoost * 10 - gaslightSignals * 5, 0, 100),
    gaslighting: clamp(gaslightSignals * 12, 0, 100),
    hiddenAgenda: clamp(hiddenAgendaSignals * 15, 0, 100),
    miscommunication: clamp(miscommunicationSignals * 12, 0, 100),
    inLove: clamp(loveSignals * 15, 0, 100),
    flirting: clamp(flirtSignals * 15, 0, 100),
    shy: clamp(shySignals * 10, 0, 100),
  };

  const sum =
    metrics.honesty +
    (100 - metrics.gaslighting) +
    (100 - metrics.hiddenAgenda) +
    (100 - metrics.miscommunication) +
    metrics.inLove +
    metrics.flirting +
    metrics.shy;

  const overallScore = clamp(Math.round(sum / 7), 0, 100);

  const notes = [];

  if (metrics.gaslighting >= 50) {
    notes.push('The conversation shows strong indicators of manipulative or dismissive language.');
  } else if (metrics.gaslighting >= 20) {
    notes.push('There are some mild signs of dismissive or minimizing language.');
  }

  if (metrics.hiddenAgenda >= 40) {
    notes.push('There may be implied conditions or hidden motives in the wording.');
  }

  if (metrics.miscommunication >= 40) {
    notes.push('There are signs of misunderstanding or misaligned expectations.');
  }

  if (metrics.inLove >= 40 || metrics.flirting >= 40) {
    notes.push('The conversation has clear romantic or flirty energy.');
  } else if (metrics.inLove >= 20 || metrics.flirting >= 20) {
    notes.push('There are some subtle romantic or flirty cues.');
  }

  if (metrics.shy >= 40) {
    notes.push('One or both people sound hesitant, shy, or unsure.');
  }

  if (notes.length === 0) {
    notes.push('The conversation looks relatively neutral with no strong red flags.');
  }

  let summary = 'The conversation appears relatively neutral.';
  if (metrics.gaslighting >= 60 || metrics.hiddenAgenda >= 60) {
    summary = 'The conversation shows potential red flags around manipulation or hidden motives.';
  } else if (metrics.miscommunication >= 60) {
    summary = 'The conversation shows strong signs of miscommunication or misunderstanding.';
  } else if (metrics.inLove >= 50 || metrics.flirting >= 50) {
    summary = 'The conversation has a clearly romantic or flirty vibe.';
  } else if (metrics.honesty >= 70 && metrics.gaslighting <= 20) {
    summary = 'The conversation seems mostly honest and straightforward.';
  }

  return {
    overallScore,
    metrics,
    summary,
    notes,
  };
}

module.exports = {
  analyzeTextToMetrics,
};
"@

# ================================
# server/routes/analyze.js
# ================================
$analyzeRoute = @"
const express = require('express');
const { analyzeTextToMetrics } = require('../analyzeLogic');
const { randomUUID } = require('crypto');

const router = express.Router();

const MAX_TEXT_LENGTH = 8000;

router.post('/analyze', (req, res) => {
  const requestId = randomUUID();
  const timestamp = new Date().toISOString();

  try {
    const body = req.body || {};
    const text = typeof body.text === 'string' ? body.text : '';
    const metadata = body.metadata || {};

    if (text.trim().length === 0) {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: "The 'text' field is required and must be a non-empty string.",
          details: null,
        },
        requestId,
        timestamp,
      });
    }

    if (text.length > MAX_TEXT_LENGTH) {
      return res.status(413).json({
        ok: false,
        error: {
          code: 'PAYLOAD_TOO_LARGE',
          message: "The conversation is too long. Please limit to " + MAX_TEXT_LENGTH + " characters.",
          details: { maxLength: MAX_TEXT_LENGTH },
        },
        requestId,
        timestamp,
      });
    }

    const analysis = analyzeTextToMetrics(text);

    return res.json({
      ok: true,
      analysis: {
        summary: analysis.summary,
        overallScore: analysis.overallScore,
        metrics: analysis.metrics,
        notes: analysis.notes,
      },
      requestId,
      timestamp,
    });
  } catch (err) {
    console.error('Error in /analyze route:', err);

    return res.status(500).json({
      ok: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Something went wrong while analyzing the conversation.',
        details: null,
      },
      requestId,
      timestamp,
    });
  }
});

module.exports = router;
"@

# ================================
# server/index.js
# ================================
$serverIndexContent = @"
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const analyzeRouter = require('./routes/analyze');

const app = express();

const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use('/', analyzeRouter);

app.listen(PORT, () => {
  console.log('Confusion-AI backend listening on port ' + PORT);
});
"@

# ================================
# Write all files
# ================================
Write-FileWithBackup "api-contracts\analyze.json.md" $apiContract
Write-FileWithBackup "frontend\.env.development.local" $envDev
Write-FileWithBackup "frontend\.env.production" $envProd
Write-FileWithBackup "server\.env" $serverEnv
Write-FileWithBackup "frontend\src\types\analyze.ts" $frontendTypes
Write-FileWithBackup "frontend\src\config\api.ts" $frontendApi
Write-FileWithBackup "frontend\src\App.tsx" $frontendApp
Write-FileWithBackup "server\analyzeLogic.js" $analyzeLogic
Write-FileWithBackup "server\routes\analyze.js" $analyzeRoute
Write-FileWithBackup "server\index.js" $serverIndexContent

Write-Host ""
Write-Host "=== Done. Files updated for Confusion-AI Phase 2 (items 5–8) ==="
Write-Host "Next steps:"
Write-Host "1) Backend: cd `"$root\server`" ; npm install express cors dotenv ; node index.js"
Write-Host "2) Frontend: cd `"$root\frontend`" ; npm install ; npm run dev"
