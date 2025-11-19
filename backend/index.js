const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const VIBE_MODES = [
  "calm",
  "positive",
  "tense",
  "hostile",
  "confused",
  "in_love",
  "flirty",
  "shy",
];

function randomBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomUnit() {
  return parseFloat(Math.random().toFixed(2));
}

function buildMockAnalysis(payload) {
  const vibe =
    VIBE_MODES[Math.floor(Math.random() * VIBE_MODES.length)] || "calm";

  const score = randomBetween(40, 95);
  const sentiment = randomUnit();
  const tension = randomUnit();
  const honesty = randomUnit();
  const gaslighting = randomUnit();
  const hiddenAgenda = randomUnit();
  const miscommunication = randomUnit();
  const inLove = randomUnit();
  const flirting = randomUnit();
  const shy = randomUnit();

  const anonymousMode =
    typeof payload?.anonymousMode === "boolean"
      ? payload.anonymousMode
      : true;

  const isProUser = true;

  const summary =
    "This is a mocked VibeGauge analysis summary. The conversation appears generally calm with pockets of emotional nuance. Use this as a visual demo while wiring up the real model.";

  const psychEval = isProUser
    ? "Mock psych evaluation for demo purposes only. In production, this would contain a richer narrative about relational dynamics, tension patterns, and communication styles."
    : undefined;

  return {
    vibe,
    score,
    sentiment,
    tension,
    honesty,
    gaslighting,
    hiddenAgenda,
    miscommunication,
    inLove,
    flirting,
    shy,
    summary,
    isProUser,
    psychEval,
    anonymousMode,
  };
}

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

app.post("/analyze", (req, res) => {
  try {
    const { messages, metadata, anonymousMode } = req.body || {};
    const result = buildMockAnalysis({ messages, metadata, anonymousMode });
    res.json(result);
  } catch (err) {
    console.error("Error in /analyze:", err);
    res.status(500).json({ error: "Failed to build mock analysis." });
  }
});

const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log(`VibeGauge backend listening on port ${PORT}`);
});