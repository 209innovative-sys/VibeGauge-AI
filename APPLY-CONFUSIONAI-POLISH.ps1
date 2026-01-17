# APPLY-CONFUSIONAI-POLISH.ps1
# Run from repo root:  C:\Users\Alexi\Desktop\VibeGauge-AI
# This script:
# - Fixes TypeScript import.meta.env typing (vite-env.d.ts)
# - Adds screenshot OCR -> textarea autofill support (expects backend returns extractedText)
# - Adds conversation speaker differentiation + bubble preview
# - Makes "Innovative Solutions" a non-clickable insignia
# - Adds Firebase Auth (Login / Sign up / Sign out)
# - Installs firebase using npm.cmd (bypasses npm.ps1 StrictMode issues)
# - Creates backups before overwriting

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

function Section([string]$t) { Write-Host ""; Write-Host "==================== $t ====================" -ForegroundColor Cyan }
function WriteUtf8NoBom([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content.Replace("`r`n","`n").Replace("`n","`r`n"), $enc)
}
function BackupIfExists([string]$src, [string]$backupRoot) {
  if (Test-Path $src) {
    $rel = $src.Replace($RepoRoot + "\", "")
    $dest = Join-Path $backupRoot $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    Copy-Item -Force $src $dest
    Write-Host "Backed up: $rel -> $($dest)" -ForegroundColor DarkGray
  }
}
function EnsureGitignoreLine([string]$path, [string]$line) {
  if (-not (Test-Path $path)) { WriteUtf8NoBom $path "" }
  $cur = Get-Content -Path $path -ErrorAction SilentlyContinue
  if ($cur -notcontains $line) {
    Add-Content -Path $path -Value $line
  }
}
function CmdExists([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

Section "Resolve repo root"
if (-not (CmdExists "git")) { throw "git not found in PATH." }

$RepoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $RepoRoot) { throw "Not inside a git repo. Run from inside the repo." }
Set-Location $RepoRoot
Write-Host "RepoRoot: $RepoRoot"

$FrontendDir = Join-Path $RepoRoot "frontend"
if (-not (Test-Path $FrontendDir)) { throw "Missing frontend folder at: $FrontendDir" }

$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
$BackupRoot = Join-Path $RepoRoot ("_autobackups\polish-" + $ts)
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
Write-Host "Backups -> $BackupRoot" -ForegroundColor DarkGray

Section "Back up files that will be overwritten"
$filesToBackup = @(
  "frontend\src\App.tsx",
  "frontend\src\components\ConversationPreview.tsx",
  "frontend\src\components\ScreenshotUpload.tsx"
)
foreach ($f in $filesToBackup) { BackupIfExists (Join-Path $RepoRoot $f) $BackupRoot }

Section "Write/Replace frontend files"

# 1) vite-env typing (fixes import.meta.env TS error)
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\vite-env.d.ts") @"
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string;

  // Firebase (frontend-safe)
  readonly VITE_FIREBASE_API_KEY?: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN?: string;
  readonly VITE_FIREBASE_PROJECT_ID?: string;
  readonly VITE_FIREBASE_APP_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
"@

# 2) shared types
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\types\analysis.ts") @"
export type Metric = {
  score: number | string;
  reason: string;
};

export type AnalysisResult = {
  honesty?: Metric;
  gaslighting?: Metric;
  hiddenAgenda?: Metric;
  miscommunication?: Metric;
  inLove?: Metric;
  flirting?: Metric;
  shy?: Metric;
  summary: string;

  // OCR text from screenshot (backend should return this)
  extractedText?: string;
};
"@

# 3) conversation parsing
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\utils\parseConversation.ts") @"
export type ConversationMessage = { speaker: string; text: string };
export type ConversationData = { participants: string[]; messages: ConversationMessage[] };

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

const speakerPrefix = (line: string): { speaker: string; rest: string } | null => {
  const m = line.match(/^([A-Za-z][A-Za-z0-9 _-]{0,32})\s*:\s*(.+)$/);
  if (!m) return null;
  const speaker = clean(m[1]);
  const rest = clean(m[2]);
  if (!speaker || !rest) return null;
  return { speaker, rest };
};

export function parseConversation(raw: string): ConversationData | null {
  const input = (raw ?? "").trim();
  if (!input) return null;

  const lines = input
    .split(/\r?\n/)
    .map(clean)
    .filter(Boolean);

  // Strategy 1: "Name: message"
  const msgs: ConversationMessage[] = [];
  let curSpeaker: string | null = null;
  let buf: string[] = [];

  const flush = () => {
    if (curSpeaker && buf.length) msgs.push({ speaker: curSpeaker, text: buf.join(" ") });
    buf = [];
  };

  for (const line of lines) {
    const pref = speakerPrefix(line);
    if (pref) {
      flush();
      curSpeaker = pref.speaker;
      buf.push(pref.rest);
    } else if (curSpeaker) {
      buf.push(line);
    }
  }
  flush();

  const speakers = Array.from(new Set(msgs.map((m) => m.speaker)));
  if (msgs.length >= 2 && speakers.length >= 2) {
    return { participants: speakers.slice(0, 4), messages: msgs };
  }

  // Strategy 2: fallback “Person A/B” alternating
  const chunks =
    input.split(/\n\s*\n/g).map(clean).filter(Boolean).length >= 2
      ? input.split(/\n\s*\n/g).map(clean).filter(Boolean)
      : lines;

  const A = "Person A";
  const B = "Person B";
  return {
    participants: [A, B],
    messages: chunks.map((t, i) => ({ speaker: i % 2 === 0 ? A : B, text: t })),
  };
}
"@

# 4) ConversationPreview (bubble view)
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\components\ConversationPreview.tsx") @"
import React from "react";
import type { ConversationData } from "../utils/parseConversation";

export default function ConversationPreview({
  conversation,
}: {
  conversation: ConversationData | null;
}) {
  if (!conversation || conversation.messages.length === 0) return null;

  const speakerClass = (idx: number) => {
    if (idx === 0) return "border-cyan-500/40 bg-cyan-500/10 text-cyan-100";
    if (idx === 1) return "border-fuchsia-500/40 bg-fuchsia-500/10 text-fuchsia-100";
    if (idx === 2) return "border-emerald-500/40 bg-emerald-500/10 text-emerald-100";
    return "border-slate-500/40 bg-slate-500/10 text-slate-100";
  };

  const map = new Map<string, number>();
  conversation.participants.forEach((p, i) => map.set(p, i));

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950/40 p-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-[11px] font-semibold text-slate-200">Detected people:</span>
        {conversation.participants.map((p, i) => (
          <span
            key={p}
            className={`rounded-full border px-2 py-1 text-[10px] font-semibold ${speakerClass(i)}`}
          >
            {p}
          </span>
        ))}
      </div>

      <div className="mt-3 max-h-[240px] overflow-auto space-y-2 pr-1">
        {conversation.messages.slice(0, 80).map((m, idx) => {
          const si = map.get(m.speaker) ?? 0;
          const isLeft = si % 2 === 0;

          return (
            <div key={idx} className={`flex ${isLeft ? "justify-start" : "justify-end"}`}>
              <div className={`max-w-[85%] rounded-2xl border px-3 py-2 text-xs ${speakerClass(si)}`}>
                <div className="mb-1 text-[10px] font-bold opacity-90">{m.speaker}</div>
                <div className="text-slate-100">{m.text}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
"@

# 5) ScreenshotUpload (expects extractedText optional)
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\components\ScreenshotUpload.tsx") @"
import React, { useEffect, useState } from "react";
import type { AnalysisResult } from "../types/analysis";

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

  const apiBase = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
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
    setPreviewUrl(URL.createObjectURL(selected));
  };

  const handleUpload = async () => {
    if (!file) {
      const msg = "Choose a screenshot first.";
      setLocalError(msg);
      onError(msg);
      return;
    }

    if (!canAnalyze()) return;

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
        throw new Error(body || `Screenshot analysis failed with ${res.status}`);
      }

      const data = (await res.json()) as AnalysisResult;
      onResult(data);
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Unexpected screenshot analysis error.";
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
"@

# 6) Firebase Auth scaffolding
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\lib\firebase.ts") @"
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY as string,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN as string,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID as string,
  appId: import.meta.env.VITE_FIREBASE_APP_ID as string,
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
"@

WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\hooks\useAuth.ts") @"
import { useEffect, useState } from "react";
import type { User } from "firebase/auth";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { auth } from "../lib/firebase";

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setAuthLoading(false);
    });
    return () => unsub();
  }, []);

  const logout = async () => {
    await signOut(auth);
  };

  return { user, authLoading, logout };
}
"@

WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\components\AuthModal.tsx") @"
import React, { useState } from "react";
import { createUserWithEmailAndPassword, signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "../lib/firebase";

export default function AuthModal({
  open,
  mode,
  onClose,
  onModeChange,
}: {
  open: boolean;
  mode: "login" | "signup";
  onClose: () => void;
  onModeChange: (m: "login" | "signup") => void;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (!open) return null;

  const submit = async () => {
    setErr(null);
    setBusy(true);
    try {
      if (mode === "signup") {
        await createUserWithEmailAndPassword(auth, email.trim(), password);
      } else {
        await signInWithEmailAndPassword(auth, email.trim(), password);
      }
      onClose();
    } catch (e: any) {
      setErr(e?.message ?? "Auth failed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-950 p-4">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-slate-100">
            {mode === "signup" ? "Create account" : "Log in"}
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-slate-700 bg-slate-900/50 px-2 py-1 text-xs text-slate-200 hover:bg-slate-800/60"
          >
            Close
          </button>
        </div>

        {err && (
          <div className="mt-3 rounded-xl border border-red-500/30 bg-red-500/10 p-2 text-xs text-red-200">
            {err}
          </div>
        )}

        <div className="mt-3 space-y-2">
          <input
            className="w-full rounded-xl border border-slate-700 bg-slate-900/40 px-3 py-2 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-cyan-500/40"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
          />
          <input
            className="w-full rounded-xl border border-slate-700 bg-slate-900/40 px-3 py-2 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-cyan-500/40"
            placeholder="Password (6+ chars)"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete={mode === "signup" ? "new-password" : "current-password"}
          />
        </div>

        <button
          type="button"
          onClick={submit}
          disabled={busy || !email.trim() || password.length < 6}
          className="mt-3 w-full rounded-xl bg-emerald-500 px-4 py-2 text-xs font-bold text-slate-950 hover:bg-emerald-400 disabled:opacity-60"
        >
          {busy ? "Please wait..." : mode === "signup" ? "Sign up" : "Log in"}
        </button>

        <div className="mt-3 flex items-center justify-between text-[11px] text-slate-400">
          <span>{mode === "signup" ? "Already have an account?" : "Need an account?"}</span>
          <button
            type="button"
            onClick={() => onModeChange(mode === "signup" ? "login" : "signup")}
            className="font-semibold text-cyan-300 hover:text-cyan-200"
          >
            {mode === "signup" ? "Log in" : "Sign up"}
          </button>
        </div>
      </div>
    </div>
  );
}
"@

# 7) App.tsx (complete replacement – includes insignia, auth buttons, screenshot extractedText autofill, speaker bubbles)
WriteUtf8NoBom (Join-Path $RepoRoot "frontend\src\App.tsx") @"
import React, { useEffect, useMemo, useState } from "react";
import ScreenshotUpload from "./components/ScreenshotUpload";
import BrandWatermark from "./components/BrandWatermark";
import VibeGauge, { CompatibilityMode } from "./components/VibeGauge";
import ConversationPreview from "./components/ConversationPreview";
import AuthModal from "./components/AuthModal";
import { useAuth } from "./hooks/useAuth";
import { parseConversation } from "./utils/parseConversation";
import type { AnalysisResult, Metric } from "./types/analysis";

const FREE_DAILY_LIMIT = 5;
const USAGE_KEY = "confusionai_usage_v1";
const PRO_KEY = "confusionai_isPro_v1";

const getToday = () => new Date().toISOString().slice(0, 10);

const toScore = (metric?: Metric): number | null => {
  if (!metric) return null;
  const raw = String(metric.score).trim().replace(/%$/, "");
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  return Math.max(0, Math.min(100, n));
};

const average = (values: (number | null | undefined)[]): number | null => {
  const nums = values.filter((v): v is number => typeof v === "number" && Number.isFinite(v));
  if (nums.length === 0) return null;
  const sum = nums.reduce((acc, v) => acc + v, 0);
  return sum / nums.length;
};

const deriveCompatibility = (
  result: AnalysisResult | null
): { mode: CompatibilityMode; overall: number | null } => {
  if (!result) return { mode: "mixed", overall: null };

  const honesty = toScore(result.honesty);
  const gaslighting = toScore(result.gaslighting);
  const hidden = toScore(result.hiddenAgenda);
  const miscommunication = toScore(result.miscommunication);
  const inLove = toScore(result.inLove);
  const flirting = toScore(result.flirting);

  const negativity = average([gaslighting, hidden, miscommunication]);
  const romance = average([inLove, flirting]);
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
    overall = 100 - negativity;
  } else if (mode === "in_love" && romance !== null) {
    overall = romance;
  } else if (mode === "honest" && honestyScore !== null) {
    overall = honestyScore;
  } else {
    overall = average([honesty, romance, negativity !== null ? 100 - negativity : null]);
  }

  if (overall === null || !Number.isFinite(overall)) return { mode, overall: null };
  return { mode, overall: Math.max(0, Math.min(100, overall)) };
};

const compatibilityTheme: Record<CompatibilityMode, { base: string; glow: string; accentPill: string }> = {
  mixed: {
    base: "bg-slate-950",
    glow: "bg-[radial-gradient(circle_at_top,_rgba(148,163,184,0.35),_rgba(15,23,42,0.98))]",
    accentPill: "text-slate-200 border-slate-400",
  },
  honest: {
    base: "bg-slate-950",
    glow: "bg-[radial-gradient(circle_at_top,_rgba(34,197,94,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-emerald-300 border-emerald-500/60",
  },
  toxic: {
    base: "bg-slate-950",
    glow: "bg-[radial-gradient(circle_at_top,_rgba(248,113,113,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-red-300 border-red-500/60",
  },
  in_love: {
    base: "bg-slate-950",
    glow: "bg-[radial-gradient(circle_at_top,_rgba(59,130,246,0.55),_rgba(15,23,42,0.98))]",
    accentPill: "text-sky-300 border-sky-500/60",
  },
};

const App: React.FC = () => {
  const [text, setText] = useState("");
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const [isPro, setIsPro] = useState(false);
  const [dailyCount, setDailyCount] = useState(0);

  const [isCreatingCheckout, setIsCreatingCheckout] = useState(false);

  const { user, logout } = useAuth();
  const [authOpen, setAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");

  const apiBase = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  const { mode, overall } = useMemo(() => deriveCompatibility(result), [result]);
  const theme = compatibilityTheme[mode];

  const conversation = useMemo(() => parseConversation(text), [text]);

  useEffect(() => {
    const today = getToday();

    try {
      const storedUsage = localStorage.getItem(USAGE_KEY);
      if (storedUsage) {
        const parsed = JSON.parse(storedUsage) as { date?: string; count?: number };
        if (parsed.date === today && typeof parsed.count === "number") {
          setDailyCount(parsed.count);
        } else {
          localStorage.setItem(USAGE_KEY, JSON.stringify({ date: today, count: 0 }));
          setDailyCount(0);
        }
      } else {
        localStorage.setItem(USAGE_KEY, JSON.stringify({ date: today, count: 0 }));
        setDailyCount(0);
      }
    } catch {}

    try {
      const storedPro = localStorage.getItem(PRO_KEY);
      if (storedPro === "true") setIsPro(true);

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
    } catch {}
  }, []);

  const recordAnalysis = () => {
    const today = getToday();
    setDailyCount((prev) => {
      const next = prev + 1;
      try {
        localStorage.setItem(USAGE_KEY, JSON.stringify({ date: today, count: next }));
      } catch {}
      return next;
    });
  };

  const canRunAnotherAnalysis = () => {
    if (isLoading) return false;
    if (isPro) return true;

    if (dailyCount >= FREE_DAILY_LIMIT) {
      setError(`Free plan: ${FREE_DAILY_LIMIT} analyses per day. Upgrade to Pro for unlimited.`);
      return false;
    }
    return true;
  };

  const handleAnalyzeText = async () => {
    if (!text.trim()) {
      setError("Paste a conversation first.");
      return;
    }
    if (!canRunAnotherAnalysis()) return;

    setIsLoading(true);
    setError(null);

    try {
      const res = await fetch(`${apiBase}/analyze`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text }),
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Text analysis failed with ${res.status}`);
      }

      const data = (await res.json()) as AnalysisResult;
      setResult(data);
      recordAnalysis();
    } catch (err: any) {
      setError(err?.message ?? "Unexpected analysis error.");
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
        headers: { "Content-Type": "application/json" },
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `Upgrade failed (${res.status})`);
      }

      const data = (await res.json()) as { url?: string };
      if (data.url) window.location.href = data.url;
      else throw new Error("No checkout URL returned.");
    } catch (err: any) {
      setError(err?.message ?? "Upgrade failed.");
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
          <span className="text-emerald-400">{n.toFixed(0)}/100</span>
        </div>
        <p className="mt-1 text-xs text-slate-300">{metric.reason}</p>
      </div>
    );
  };

  const compatibilityPillLabel =
    mode === "honest" ? "Compatibility: Honest" :
    mode === "toxic" ? "Compatibility: Toxic" :
    mode === "in_love" ? "Compatibility: In Love" :
    "Compatibility: Mixed";

  const planPillLabel = isPro ? "Pro: unlimited analyses" : `Free: ${dailyCount}/${FREE_DAILY_LIMIT} today`;
  const planPillClass = isPro ? "border-cyan-400 text-cyan-300" : "border-emerald-400 text-emerald-300";

  return (
    <div className={`relative min-h-screen text-slate-50 transition-colors duration-700 ${theme.base}`}>
      <div className={`pointer-events-none absolute inset-0 -z-10 opacity-70 blur-3xl ${theme.glow}`} />
      <div className="relative z-10">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-6">
          <header className="flex flex-col gap-3 sm:flex-row sm:items-baseline sm:justify-between">
            <div>
              <h1 className="bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-500 bg-clip-text text-3xl font-bold tracking-tight text-transparent">
                Confusion-AI
              </h1>
              <p className="text-xs text-slate-400">
                Drop in your chat or a screenshot. I&apos;ll read compatibility: honesty, gaslighting, hidden agenda,
                miscommunication, in love, flirting, and shy.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              {/* INSIGNIA (NOT A BUTTON) */}
              <div className="pointer-events-none select-none rounded-full border border-emerald-500/30 bg-emerald-500/5 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-emerald-200/90">
                Innovative Solutions
              </div>

              <span className={`rounded-full border bg-slate-900/70 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${theme.accentPill}`}>
                {compatibilityPillLabel}
              </span>

              <span className={`rounded-full border bg-slate-900/80 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide ${planPillClass}`}>
                {planPillLabel}
              </span>

              {/* AUTH */}
              {!user ? (
                <>
                  <button
                    type="button"
                    onClick={() => { setAuthMode("login"); setAuthOpen(true); }}
                    className="inline-flex items-center justify-center rounded-full border border-slate-600 bg-slate-900/60 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-100 hover:bg-slate-800/70"
                  >
                    Log in
                  </button>
                  <button
                    type="button"
                    onClick={() => { setAuthMode("signup"); setAuthOpen(true); }}
                    className="inline-flex items-center justify-center rounded-full border border-cyan-500/50 bg-cyan-500/10 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-cyan-200 hover:bg-cyan-500/20"
                  >
                    Sign up
                  </button>
                </>
              ) : (
                <>
                  <span className="text-[10px] text-slate-300">{user.email ?? "Signed in"}</span>
                  <button
                    type="button"
                    onClick={() => void logout()}
                    className="inline-flex items-center justify-center rounded-full border border-slate-600 bg-slate-900/60 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-100 hover:bg-slate-800/70"
                  >
                    Sign out
                  </button>
                </>
              )}

              {/* PRO */}
              <button
                type="button"
                onClick={handleUpgradeClick}
                disabled={isPro || isCreatingCheckout}
                className="inline-flex items-center justify-center rounded-full bg-fuchsia-500 px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-950 shadow-md shadow-fuchsia-900/40 transition hover:bg-fuchsia-400 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isPro ? "Pro active" : isCreatingCheckout ? "Redirecting..." : "Upgrade to Pro"}
              </button>
            </div>
          </header>

          <main className="grid gap-4 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            {/* LEFT */}
            <section className="flex flex-col gap-3">
              <label className="text-xs font-semibold text-slate-200">Paste conversation</label>

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
                {error && <span className="text-xs text-red-400 max-w-xs">{error}</span>}
              </div>

              <ConversationPreview conversation={conversation} />

              <ScreenshotUpload
                canAnalyze={canRunAnotherAnalysis}
                onResult={(data) => {
                  setResult(data);
                  setError(null);

                  // OCR -> fill textarea (backend must return extractedText for best results)
                  if (typeof data.extractedText === "string" && data.extractedText.trim()) {
                    setText(data.extractedText);
                  }

                  recordAnalysis();
                }}
                onError={(message) => setError(message || null)}
              />
            </section>

            {/* RIGHT */}
            <section className="flex flex-col gap-3">
              <VibeGauge score={overall} mode={mode} />

              <h2 className="text-sm font-semibold text-slate-100">Compatibility breakdown</h2>

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
                    {renderMetric("Miscommunication", result.miscommunication)}
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

        <AuthModal
          open={authOpen}
          mode={authMode}
          onClose={() => setAuthOpen(false)}
          onModeChange={setAuthMode}
        />
      </div>
    </div>
  );
};

export default App;
"@

Section "Update .gitignore to prevent env leaks (idempotent)"
$gitignore = Join-Path $RepoRoot ".gitignore"
EnsureGitignoreLine $gitignore ".env"
EnsureGitignoreLine $gitignore ".env.*"
EnsureGitignoreLine $gitignore "backend/.env"
EnsureGitignoreLine $gitignore "backend/.env.*"
EnsureGitignoreLine $gitignore "backend/.env.bak*"
EnsureGitignoreLine $gitignore "frontend/.env"
EnsureGitignoreLine $gitignore "frontend/.env.*"

Section "Install firebase + build (using npm.cmd to bypass npm.ps1 shim)"
$npmCmd = (Get-Command "npm.cmd" -ErrorAction SilentlyContinue).Source
if (-not $npmCmd) { throw "npm.cmd not found. Node/NPM install looks broken." }

Push-Location $FrontendDir
try {
  & $npmCmd -v
  & $npmCmd i firebase
  if ($LASTEXITCODE -ne 0) { throw "npm.cmd install failed with exit code $LASTEXITCODE" }

  & $npmCmd run build
  if ($LASTEXITCODE -ne 0) { throw "npm.cmd run build failed with exit code $LASTEXITCODE" }

  Write-Host "✅ Frontend deps + build OK" -ForegroundColor Green
} finally {
  Pop-Location
}

Section "Find backend /analyze-image route (so you can add extractedText in response)"
$backendDir = Join-Path $RepoRoot "backend"
if (Test-Path $backendDir) {
  $hits = Get-ChildItem -Path $backendDir -Recurse -File -ErrorAction SilentlyContinue |
    Select-String -Pattern "analyze-image|/analyze-image|analyzeImage" -SimpleMatch -ErrorAction SilentlyContinue

  if ($hits) {
    $hits | Select-Object -First 10 | ForEach-Object {
      Write-Host ("HIT: {0}:{1} -> {2}" -f $_.Path.Replace($RepoRoot + "\", ""), $_.LineNumber, $_.Line.Trim()) -ForegroundColor Yellow
    }
    Write-Host "NOTE: backend /analyze-image should return extractedText, e.g. res.json({ ...analysisResult, extractedText })" -ForegroundColor Yellow
  } else {
    Write-Host "No /analyze-image references found under backend/. You may need to locate the route manually." -ForegroundColor Yellow
  }
} else {
  Write-Host "No backend/ folder found (skipping backend scan)." -ForegroundColor Yellow
}

Section "Git summary + optional branch + commit"
git status -sb | Out-Host

# Create a branch name that matches your org pattern (slash style works for you)
$branch = "feat/polish/auth-screenshot-$ts"
$current = (git rev-parse --abbrev-ref HEAD).Trim()

if ($current -eq "main") {
  git switch -c $branch | Out-Host
  Write-Host "Switched to new branch: $branch" -ForegroundColor Green
} elseif ($current -ne $branch) {
  Write-Host "Current branch: $current (not switching)" -ForegroundColor DarkGray
}

# Stage and commit if there are changes
git add frontend/src backend/.env.example 2>$null | Out-Null
git add .gitignore | Out-Null

$staged = (git diff --cached --name-only)
if ($staged) {
  git commit -m "Polish: screenshot speaker bubbles + Firebase auth + env typings" | Out-Host
} else {
  Write-Host "No staged changes to commit." -ForegroundColor DarkGray
}

# Push branch (best effort)
try {
  git push -u origin (git rev-parse --abbrev-ref HEAD) | Out-Host
} catch {
  Write-Host "Push failed (okay). Create PR manually after pushing with your normal flow." -ForegroundColor Yellow
}

Section "DONE"
Write-Host "Next steps (required in Vercel env vars): VITE_FIREBASE_API_KEY, VITE_FIREBASE_AUTH_DOMAIN, VITE_FIREBASE_PROJECT_ID, VITE_FIREBASE_APP_ID" -ForegroundColor Yellow
Write-Host "Backend note: /analyze-image should return extractedText so screenshot OCR fills the textarea + speaker parsing works." -ForegroundColor Yellow
