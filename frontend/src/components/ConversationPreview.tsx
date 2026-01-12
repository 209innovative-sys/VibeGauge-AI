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
            className={ounded-full border px-2 py-1 text-[10px] font-semibold }
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
            <div key={idx} className={lex }>
              <div className={max-w-[85%] rounded-2xl border px-3 py-2 text-xs }>
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