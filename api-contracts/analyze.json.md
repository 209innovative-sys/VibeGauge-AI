# Confusion-AI `/analyze` API Contract (v1)

## Endpoint

- Method: `POST`
- URL: `https://confusion-ai.onrender.com/analyze`
- Content-Type: `application/json`

## Request Body

```jsonc
{
  "text": "string - required, conversation text to analyze",
  "metadata": {
    "source": "string - optional, e.g. 'web', 'android', 'ios'",
    "language": "string - optional, e.g. 'en'",
    "clientVersion": "string - optional, e.g. '1.0.0'"
  }
}
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
