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
Scores are 0â€“100.
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

  console.log("âœ“ /analyze-image route registered");
}

module.exports = { registerAnalyzeImageRoute };
