import React from "react";

type Props = {
  onTry: () => void;
};

export default function Landing({ onTry }: Props) {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center px-6">
      <div className="max-w-3xl w-full text-center space-y-8">

        {/* Logo / Title */}
        <h1 className="text-4xl sm:text-5xl font-extrabold tracking-tight
          bg-gradient-to-r from-cyan-400 via-blue-400 to-fuchsia-500
          bg-clip-text text-transparent">
          Confusion-AI
        </h1>

        <p className="text-slate-300 text-lg">
          See the vibe before you reply.
        </p>

        {/* Gauge */}
        <div className="relative mx-auto h-6 w-full max-w-md rounded-full overflow-hidden bg-slate-800">
          <div className="absolute inset-0 bg-gradient-to-r from-blue-400 via-cyan-400 to-red-500 animate-pulse" />
        </div>

        {/* Benefits */}
        <ul className="text-sm text-slate-300 space-y-2">
          <li>• Analyze emotional tone & conflict</li>
          <li>• Detect red flags & mixed signals</li>
          <li>• Paste text or upload screenshots</li>
        </ul>

        {/* CTA */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center pt-6">
          <button
            onClick={onTry}
            data-cta="primary"
            className="rounded-full bg-cyan-400 px-8 py-4
              text-slate-900 font-semibold text-sm
              shadow-lg shadow-cyan-900/40
              hover:bg-cyan-300 transition"
          >
            Try Confusion-AI
          </button>

          <button
            data-cta="secondary"
            className="rounded-full border border-slate-700 px-8 py-4
              text-sm text-slate-300 hover:border-slate-500 transition"
            onClick={() => {
              const email = prompt("Enter your email for early access:");
              if (!email) return;
              const list = JSON.parse(localStorage.getItem("confusionai_waitlist") || "[]");
              list.push({ email, date: new Date().toISOString() });
              localStorage.setItem("confusionai_waitlist", JSON.stringify(list));
              alert("You're on the list 🚀");
            }}
          >
            Get Early Access
          </button>
        </div>

        {/* Trust note */}
        <p className="pt-6 text-xs text-slate-400">
          Privacy-first. Conversations are analyzed for insights only —
          no storage, no training, no creepy stuff.
        </p>

      </div>
    </div>
  );
}
