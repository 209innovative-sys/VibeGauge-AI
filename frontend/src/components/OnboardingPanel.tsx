import React, { useMemo, useState } from "react";

type BubbleProps = {
  title: string;
  body: string;
  tone?: "good" | "warn" | "info";
};

function Bubble({ title, body, tone = "info" }: BubbleProps) {
  const toneClasses =
    tone === "good"
      ? "border-emerald-500/30 bg-emerald-500/10"
      : tone === "warn"
      ? "border-fuchsia-500/30 bg-fuchsia-500/10"
      : "border-cyan-500/30 bg-cyan-500/10";

  const tail =
    tone === "good"
      ? "after:border-t-emerald-500/10"
      : tone === "warn"
      ? "after:border-t-fuchsia-500/10"
      : "after:border-t-cyan-500/10";

  return (
    <div
      className={[
        "relative rounded-3xl border p-4",
        toneClasses,
        "after:content-[''] after:absolute after:left-8 after:-bottom-3 after:border-[12px] after:border-x-transparent after:border-b-transparent",
        tail,
      ].join(" ")}
    >
      <div className="text-[11px] font-semibold uppercase tracking-wide text-slate-100/90">
        {title}
      </div>
      <div className="mt-1 text-xs text-slate-200/80 leading-relaxed">
        {body}
      </div>
    </div>
  );
}

type Props = { onFillExample: () => void };

export default function OnboardingPanel({ onFillExample }: Props) {
  const [open, setOpen] = useState(true);

  const steps = useMemo(
    () => [
      { t: "Paste or upload", b: "Paste a chat OR upload a screenshot.", tone: "info" as const },
      { t: "Tap Analyze", b: "You get compatibility + reasons + red flags.", tone: "good" as const },
      { t: "Read the signals", b: "Honesty, gaslighting, hidden agenda, miscommunication, inLove, flirting, shy.", tone: "warn" as const },
    ],
    []
  );

  return (
    <section className="rounded-3xl border border-slate-700/70 bg-slate-900/40 p-4 sm:p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold text-slate-100">Quick start</h2>
          <p className="mt-1 text-xs text-slate-300">Make it obvious for new users.</p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onFillExample}
            className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-[11px] font-semibold text-emerald-200 hover:bg-emerald-500/15"
          >
            Try sample chat
          </button>

          <button
            type="button"
            onClick={() => setOpen(v => !v)}
            className="rounded-xl border border-slate-700 bg-slate-950/40 px-3 py-2 text-[11px] font-semibold text-slate-200 hover:bg-slate-950/60"
          >
            {open ? "Hide" : "Show"}
          </button>
        </div>
      </div>

      {open && (
        <div className="mt-4 grid gap-3 md:grid-cols-3">
          {steps.map((s) => (
            <Bubble key={s.t} title={s.t} body={s.b} tone={s.tone} />
          ))}
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
        <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1">
          Tip: label speakers like â€œMe:â€ and â€œThem:â€ for cleaner results.
        </span>
        <span className="rounded-full border border-slate-700 bg-slate-950/40 px-3 py-1">
          MVP privacy: we donâ€™t store your chats on the server.
        </span>
      </div>
    </section>
  );
}