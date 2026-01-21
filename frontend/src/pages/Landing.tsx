import React from "react";

export default function Landing({ onTry }: { onTry: () => void }) {
  return (
    <div style={{ padding: 40, textAlign: "center" }}>
      <h1>Confusion-AI</h1>
      <p>Analyze emotional tone, intent, and conversational tension.</p>

      <button
        onClick={onTry}
        style={{
          marginTop: 20,
          padding: "12px 24px",
          fontSize: 18,
          cursor: "pointer"
        }}
      >
        Try Confusion-AI
      </button>
    </div>
  );
}
