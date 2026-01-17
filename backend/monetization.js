const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const Stripe = require("stripe");

const FREE_DAILY_LIMIT = Number(process.env.FREE_DAILY_LIMIT || 5);
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
      const successUrl = ${APP_PUBLIC_URL}/?success=1&session_id={CHECKOUT_SESSION_ID};
      const cancelUrl = ${APP_PUBLIC_URL}/?canceled=1;

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
      return res.status(400).send(Webhook Error: );
    }

    // For MVP we don't persist; token verification + Stripe API handles plan.
    // Keep this endpoint for future persistence + customer portal linking.
    return res.sendStatus(200);
  });
}

module.exports = { attachMonetization };