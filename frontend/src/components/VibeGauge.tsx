import React from "react";

export type CompatibilityMode = "mixed" | "honest" | "toxic" | "in_love";

type VibeGaugeProps = {
  score: number | null;
  mode: CompatibilityMode;
};

const VibeGauge: React.FC<VibeGaugeProps> = ({ score, mode }) => {
  const isPending = score == null || !Number.isFinite(score);
  const clamped = (() => {
    if (isPending) return 0;
    const n = Math.max(0, Math.min(100, score as number));
    return n;
  })();

  const radius = 60;
  const circumference = 2 * Math.PI * radius;
  const progress = (clamped / 100) * circumference;
  const offset = circumference - progress;

  const modeLabelMap: Record<CompatibilityMode, string> = {
    mixed: "Mixed",
    honest: "Honest / Grounded",
    toxic: "Toxic / Chaotic",
    in_love: "In Love / Warm",
  };

  const moodTextMap: Record<CompatibilityMode, string> = {
    mixed:
      "Compatibility is mixed. Some signals support connection, others are pulling against it.",
    honest:
      "Honesty and low manipulation signals suggest a healthy base for compatibility.",
    toxic:
      "High levels of tension, gaslighting, or hidden agenda are dragging compatibility down.",
    in_love:
      "Romantic and flirty signals are strong. Emotional connection looks high here.",
  };

  const accentClassMap: Record<CompatibilityMode, string> = {
    mixed: "text-slate-200",
    honest: "text-emerald-300",
    toxic: "text-red-300",
    in_love: "text-sky-300",
  };

  const activeMode: CompatibilityMode = isPending ? "mixed" : mode;
  const label = isPending ? "Waiting for analysis" : modeLabelMap[activeMode];
  const moodText = isPending
    ? "Run a text or screenshot analysis to see compatibility light up."
    : moodTextMap[activeMode];
  const accent = accentClassMap[activeMode];

  return (
    <div className="flex items-center gap-4 rounded-2xl border border-slate-800 bg-slate-950/70 p-4 shadow-lg shadow-slate-950/60">
      <div className="relative h-32 w-32">
        <svg viewBox="0 0 160 160" className="h-full w-full">
          <defs>
            <linearGradient
              id="compatibilityGaugeGradient"
              x1="0%"
              y1="0%"
              x2="100%"
              y2="0%"
            >
              <stop offset="0%" stopColor="#22c55e" />
              <stop offset="50%" stopColor="#0ea5e9" />
              <stop offset="100%" stopColor="#f97373" />
            </linearGradient>
          </defs>
          <circle
            cx="80"
            cy="80"
            r={radius}
            stroke="#1f2937"
            strokeWidth="14"
            fill="none"
          />
          <circle
            cx="80"
            cy="80"
            r={radius}
            stroke="url(#compatibilityGaugeGradient)"
            strokeWidth="14"
            fill="none"
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            className="transition-all duration-700 ease-out"
            style={{ transformOrigin: "80px 80px", transform: "rotate(-90deg)" }}
          />
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-[10px] font-semibold uppercase tracking-[0.25em] text-slate-500">
            Compatibility
          </span>
          <span className={`text-3xl font-bold ${accent}`}>
            {clamped.toFixed(0)}
          </span>
          <span className="mt-1 text-[11px] text-slate-400">{label}</span>
        </div>
      </div>
      <div className="flex flex-1 flex-col gap-2 text-xs">
        <p className="text-slate-300">{moodText}</p>
        <p className="text-[10px] text-slate-500">
          Derived from honesty, gaslighting, hidden agenda, miscommunication,
          in love, and flirting signals in this conversation.
        </p>
      </div>
    </div>
  );
};

export default VibeGauge;
