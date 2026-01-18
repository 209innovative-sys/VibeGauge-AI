param(
  [string]$RepoRoot = ".",
  [string]$BackendDir = "backend",
  [string]$FrontendDir = "frontend",
  [int]$FreeDailyLimit = 5
)

Write-Host "=== ADD Stripe no-login Pro + Free limit ===" -ForegroundColor Cyan

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

try { $root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path } catch { Write-Error "Repo root not found"; exit 1 }
Set-Location $root

$backendPath = Join-Path $root $BackendDir
$frontendPath = Join-Path $root $FrontendDir

if (-not (Test-Path $backendPath)) { Write-Error "Missing backend folder: $backendPath"; exit 1 }
if (-not (Test-Path $frontendPath)) { Write-Error "Missing frontend folder: $frontendPath"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $root ("backup_stripe_monetization_" + $ts)
New-Item -ItemType Directory -Path $backup | Out-Null
Write-Host "Backup dir: $backup" -ForegroundColor DarkGray

# ---------- BACKEND: add monetization module ----------
$monPath = Join-Path $backendPath "monetization.js"
if (Test-Path $monPath) { Copy-Item $monPath (Join-Path $backup "backend_monetization.js") -Force }

$mon = @"
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const Stripe = require("stripe");

const FREE_DAILY_LIMIT = Number(process.env.FREE_DAILY_LIMIT || ${FreeDailyLimit});
const APP_PUBLIC_URL = process.env.APP_PUBLIC_URL;

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const STRIPE_PRICE_ID = process.env.STRIPE_PRICE_ID;
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const JWT_SECRET = process.env.JWT_SECRET;

if (!APP_PUBLIC_URL) console.warn("[monetization] APP_PUBLIC_URL missing");
if (!STRIPE_SECRET_KEY) console.warn("[monetization] STRIPE_SECRET_KEY missing");
if (!STRIPE_PRICE_ID) console.warn("[monetization] STRIPE_PRICE_ID missing");
if (!STRIPE_WEBHOOK_SECRET) console.warn("[monetization] STRIPE_WEBHOOK_SECRET missing");
if (!JWT_SECRET) console.warn("[monetization] JWT_SECRET missing");

const stripe = STRIPE_SECRET_KEY ? new Stripe(STRIPE_SECRET_KEY, { apiVersion: "2024-06-20" }) : null;

// In-memory usage store (resets on backend restart; OK for MVP)
const usage = new Map(); // key -> { day: "YYYY-MM-DD", used: number }

function todayKey() {
  const d = new Date();
  return d.toISOString().slice(0, 10);
}

function getClientKey(req) {
  const client = req.headers["x-confusionai-client"];
  if (client && typeof client === "string" && client.length >= 10) return "c:" + client;
  const ip = (req.headers["x-forwarded-for"] || req.socket.remoteAddress || "").toString().split(",")[0].trim();
  return "ip:" + ip;
}

async function isProFromToken(req) {
  const auth = req.headers.authorization || "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return { pro: false };

  try {
    const token = m[1];
    const payload = jwt.verify(token, JWT_SECRET);
    if (!payload || payload.plan !== "pro") return { pro: false };

    // OPTIONAL: verify subscription status with Stripe if subscriptionId present
    if (stripe && payload.subscriptionId) {
      try {
        const sub = await stripe.subscriptions.retrieve(payload.subscriptionId);
        const active = ["active", "trialing"].includes(sub.status);
        return { pro: !!active, payload, stripeStatus: sub.status };
      } catch {
        return { pro: true, payload }; // fail open for MVP (avoid blocking paid users)
      }
    }

    return { pro: true, payload };
  } catch {
    return { pro: false };
  }
}

function checkAndIncrementFree(req) {
  const key = getClientKey(req);
  const today = todayKey();
  const rec = usage.get(key) || { day: today, used: 0 };

  if (rec.day !== today) {
    rec.day = today;
    rec.used = 0;
  }

  if (rec.used >= FREE_DAILY_LIMIT) {
    return { allowed: false, used: rec.used, limit: FREE_DAILY_LIMIT };
  }

  rec.used += 1;
  usage.set(key, rec);
  return { allowed: true, used: rec.used, limit: FREE_DAILY_LIMIT };
}

function attachMonetization(app) {
  // Gate analyze endpoints globally (no-login Pro token unlocks)
  app.use(["/analyze", "/analyze-image"], async (req, res, next) => {
    try {
      const proCheck = await isProFromToken(req);
      if (proCheck.pro) return next();

      const free = checkAndIncrementFree(req);
      if (!free.allowed) {
        return res.status(402).json({
          error: "Free limit reached",
          plan: "free",
          usedToday: free.used,
          freeDailyLimit: free.limit
        });
      }
      req._confusionaiUsage = free;
      next();
    } catch (e) {
      next(e);
    }
  });

  // Plan status endpoint
  app.get("/plan", async (req, res) => {
    const proCheck = await isProFromToken(req);
    if (proCheck.pro) {
      return res.json({ plan: "pro", freeDailyLimit: FREE_DAILY_LIMIT, usedToday: 0 });
    }
    const key = getClientKey(req);
    const today = todayKey();
    const rec = usage.get(key) || { day: today, used: 0 };
    const used = rec.day === today ? rec.used : 0;
    res.json({ plan: "free", freeDailyLimit: FREE_DAILY_LIMIT, usedToday: used });
  });

  // Create Checkout session
  app.post("/create-checkout-session", async (req, res) => {
    if (!stripe) return res.status(500).json({ error: "Stripe not configured" });

    try {
      const clientKey = (req.headers["x-confusionai-client"] || "").toString();
      const successUrl = `${APP_PUBLIC_URL}/?success=1&session_id={CHECKOUT_SESSION_ID}`;
      const cancelUrl = `${APP_PUBLIC_URL}/?canceled=1`;

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        line_items: [{ price: STRIPE_PRICE_ID, quantity: 1 }],
        success_url: successUrl,
        cancel_url: cancelUrl,
        metadata: {
          clientKey: clientKey || ""
        }
      });

      res.json({ url: session.url });
    } catch (e) {
      console.error("[stripe] create-checkout-session error:", e);
      res.status(500).json({ error: "Failed to create checkout session" });
    }
  });

  // Verify session -> issue Pro token
  app.post("/verify-session", async (req, res) => {
    if (!stripe) return res.status(500).json({ error: "Stripe not configured" });
    if (!JWT_SECRET) return res.status(500).json({ error: "JWT not configured" });

    try {
      const { session_id } = req.body || {};
      if (!session_id) return res.status(400).json({ error: "Missing session_id" });

      const session = await stripe.checkout.sessions.retrieve(session_id, { expand: ["subscription"] });

      // Accept "complete" checkout
      if (session.status !== "complete") {
        return res.status(400).json({ error: "Checkout not complete" });
      }

      const subId = session.subscription && typeof session.subscription === "object"
        ? session.subscription.id
        : session.subscription;

      const token = jwt.sign(
        { plan: "pro", subscriptionId: subId || null, iat: Math.floor(Date.now()/1000) },
        JWT_SECRET,
        { expiresIn: "30d" } // refreshable later
      );

      res.json({ plan: "pro", token });
    } catch (e) {
      console.error("[stripe] verify-session error:", e);
      res.status(500).json({ error: "Failed to verify session" });
    }
  });

  // Stripe webhook (optional for future hard enforcement; safe to have now)
  app.post("/stripe/webhook", require("express").raw({ type: "application/json" }), (req, res) => {
    if (!stripe || !STRIPE_WEBHOOK_SECRET) return res.sendStatus(200);

    let event;
    try {
      const sig = req.headers["stripe-signature"];
      event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error("[stripe] webhook signature failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // For MVP we don't persist; token verification + Stripe API handles plan.
    // Keep this endpoint for future persistence + customer portal linking.
    return res.sendStatus(200);
  });
}

module.exports = { attachMonetization };
"@

Write-Utf8NoBom $monPath $mon
Write-Host "Wrote: backend/monetization.js" -ForegroundColor Green

# Install backend deps
Push-Location $backendPath
Write-Host "Installing backend deps (stripe, jsonwebtoken)..." -ForegroundColor Yellow
npm i stripe jsonwebtoken
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "Backend npm install failed"; exit 1 }
Pop-Location

# Patch backend entry to attach monetization
$entryCandidates = @(
  (Join-Path $backendPath "index.js"),
  (Join-Path $backendPath "server.js")
)
$entry = $entryCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $entry) { Write-Error "Could not find backend index.js/server.js"; exit 1 }

Copy-Item $entry (Join-Path $backup ("backend_" + (Split-Path $entry -Leaf))) -Force
$entryText = Get-Content $entry -Raw

if ($entryText -notmatch "attachMonetization") {
  # Insert after "const app = express();"
  $entryText2 = $entryText -replace '(const\s+app\s*=\s*express\(\)\s*;)',
'$1
const { attachMonetization } = require("./monetization");
attachMonetization(app);
'
  if ($entryText2 -eq $entryText) {
    # fallback: append near top
    $entryText2 = $entryText + "`n`nconst { attachMonetization } = require('./monetization');`nattachMonetization(app);`n"
  }
  Write-Utf8NoBom $entry $entryText2
  Write-Host "Patched backend entry to attach monetization." -ForegroundColor Green
} else {
  Write-Host "Backend already attaches monetization." -ForegroundColor DarkGray
}

# ---------- FRONTEND: helper for Stripe flow ----------
$proLibPath = Join-Path $frontendPath "src\lib\pro.ts"
New-Item -ItemType Directory -Force -Path (Split-Path $proLibPath -Parent) | Out-Null

$proLib = @"
const TOKEN_KEY = "confusionai_pro_token";

export function getProToken(): string | null {
  try { return localStorage.getItem(TOKEN_KEY); } catch { return null; }
}

export function setProToken(token: string) {
  try { localStorage.setItem(TOKEN_KEY, token); } catch {}
}

export function getClientId(): string {
  const key = "confusionai_client_id";
  try {
    let v = localStorage.getItem(key);
    if (!v) {
      v = (crypto?.randomUUID?.() || (Math.random().toString(16).slice(2) + Date.now().toString(16)));
      localStorage.setItem(key, v);
    }
    return v;
  } catch {
    return "anon";
  }
}

export async function startCheckout(apiBase: string): Promise<void> {
  const res = await fetch(`${apiBase}/create-checkout-session`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-confusionai-client": getClientId() },
    body: JSON.stringify({})
  });
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  if (!data?.url) throw new Error("No checkout URL returned");
  window.location.href = data.url;
}

export async function completeCheckoutIfPresent(apiBase: string): Promise<"pro" | null> {
  const url = new URL(window.location.href);
  const sessionId = url.searchParams.get("session_id");
  const success = url.searchParams.get("success");
  if (!sessionId || success !== "1") return null;

  const res = await fetch(`${apiBase}/verify-session`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-confusionai-client": getClientId() },
    body: JSON.stringify({ session_id: sessionId })
  });
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  if (data?.token) setProToken(data.token);

  // Clean URL
  url.searchParams.delete("session_id");
  url.searchParams.delete("success");
  window.history.replaceState({}, "", url.toString());

  return "pro";
}
"@
Write-Utf8NoBom $proLibPath $proLib
Write-Host "Wrote: frontend/src/lib/pro.ts" -ForegroundColor Green

Write-Host "`n✅ Stripe scaffolding installed." -ForegroundColor Cyan
Write-Host "NEXT: Set Render env vars (STRIPE_SECRET_KEY, STRIPE_PRICE_ID, STRIPE_WEBHOOK_SECRET, APP_PUBLIC_URL, JWT_SECRET) then redeploy backend." -ForegroundColor Yellow
Write-Host "Then update your Upgrade button to call startCheckout(apiBase) and call completeCheckoutIfPresent(apiBase) on app load." -ForegroundColor Yellow
