import React, { useState } from "react";

export default function Analyzer({ onBack }: { onBack: () => void }) {
  const [text, setText] = useState("");
  const [result, setResult] = useState("");

  const analyze = async () => {
    const res = await fetch(import.meta.env.VITE_API_BASE + "/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text })
    });

    const data = await res.json();
    setResult(JSON.stringify(data, null, 2));
  };

  return (
    <div style={{ padding: 40 }}>
      <button onClick={onBack}>← Back</button>

      <h2>Confusion-AI Analyzer</h2>

      <textarea
        rows={6}
        style={{ width: "100%", marginTop: 10 }}
        value={text}
        onChange={(e) => setText(e.target.value)}
      />

      <br />
      <button onClick={analyze} style={{ marginTop: 10 }}>
        Analyze
      </button>

      <pre style={{ marginTop: 20 }}>{result}</pre>
    </div>
  );
}
