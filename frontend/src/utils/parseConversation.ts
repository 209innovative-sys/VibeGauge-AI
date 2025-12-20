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