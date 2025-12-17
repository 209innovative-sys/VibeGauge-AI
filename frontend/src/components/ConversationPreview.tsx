import React from "react";

type ConversationPreviewProps = {
  rawText: string;
};

type Bubble = {
  id: number;
  from: "A" | "B";
  text: string;
};

const parseConversation = (rawText: string): Bubble[] => {
  const lines = rawText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  return lines.map((text, index) => ({
    id: index,
    from: index % 2 === 0 ? "A" : "B",
    text,
  }));
};

const ConversationPreview: React.FC<ConversationPreviewProps> = ({ rawText }) => {
  const bubbles = parseConversation(rawText);

  if (bubbles.length === 0) {
    return (
      <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3 text-[11px] text-slate-500">
        Conversation preview will appear here in a chat-style layout once you paste
        messages above.
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-3">
      <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-slate-400">
        Conversation preview
      </div>
      <div className="max-h-64 space-y-1.5 overflow-y-auto pr-1 text-[11px]">
        {bubbles.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${
              msg.from === "A" ? "justify-start" : "justify-end"
            }`}
          >
            <div
              className={`max-w-[80%] rounded-2xl px-3 py-1.5 ${
                msg.from === "A"
                  ? "bg-slate-800 text-slate-100"
                  : "bg-emerald-500 text-slate-950"
              }`}
            >
              <p className="whitespace-pre-wrap leading-snug">{msg.text}</p>
            </div>
          </div>
        ))}
      </div>
      <p className="mt-2 text-[10px] text-slate-500">
        This is a visual preview only. The AI uses the raw text you pasted for
        compatibility analysis.
      </p>
    </div>
  );
};

export default ConversationPreview;
