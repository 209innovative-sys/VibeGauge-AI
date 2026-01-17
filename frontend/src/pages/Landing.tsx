import React, { useMemo, useState } from "react";
import { LandingSections } from "../components/LandingSections";

type WaitlistState = "idle" | "saved";

const APP_PATH = "/app";

function cn(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

export default function Landing() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<WaitlistState>("idle");

  const storedEmail = useMemo(() => {
    try {
      return localStorage.getItem("vibegauge_waitlist_email") || "";
    } catch {
      return "";
    }
  }, []);

  const effectiveState: WaitlistState = state === "saved" || storedEmail ? "saved" : "idle";

  const onSubmitWaitlist = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = email.trim();
    if (!trimmed) return;

    try {
      localStorage.setItem("vibegauge_waitlist_email", trimmed);
      localStorage.setItem("vibegauge_waitlist_ts", new Date().toISOString());
      setState("saved");
    } catch {
      setState("saved");
    }
  };

  const mailtoHref = useMemo(() => {
    const subject = encodeURIComponent("VibeGauge-AI Early Access");
    const body = encodeURIComponent(
      `Please add me to early access updates.\n\nEmail: ${email.trim() || "(enter email above)"}\n`
    );
    return `mailto:hello@yourdomain.com?subject=${subject}&body=${body}`;
  }, [email]);

  return (
    <main className="min-h-screen bg-[#06070B] text-white">
      {/* Background glow */}
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 opacity-70"
        style={{
          background:
            "radial-gradient(900px 450px at 20% 10%, rgba(80,140,255,0.20), transparent 60%), radial-gradient(800px 400px at 80% 20%, rgba(255,60,160,0.16), transparent 55%), radial-gradient(900px 450px at 50% 90%, rgba(255,80,60,0.14), transparent 60%)",
        }}
      />

      {/* Top bar */}
      <header className="relative z-10">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-5 sm:px-6">
          <a href="/" className="group inline-flex items-center gap-2">
            <span className="relative grid h-9 w-9 place-items-center rounded-xl border border-white/10 bg-white/5">
              <span className="h-3.5 w-3.5 rounded-full bg-white/70 shadow-[0_0_20px_rgba(120,180,255,0.55)]" />
            </span>
            <div className="leading-tight">
              <div className="text-sm font-semibold tracking-wide">VibeGauge-AI</div>
              <div className="text-xs text-white/60">aka Confusion-AI</div>
            </div>
          </a>

          <nav className="flex items-center gap-2">
            <a
              href="#faq"
              className="hidden rounded-lg px-3 py-2 text-sm text-white/70 hover:text-white sm:inline-block"
            >
              FAQ
            </a>
            <a
              href="#waitlist"
              className="rounded-lg border border-white/15 bg-white/5 px-3 py-2 text-sm text-white/80 hover:bg-white/10"
              data-cta="nav-waitlist"
            >
              Early Access
            </a>
            <a
              href={APP_PATH}
              className="rounded-lg bg-white px-3 py-2 text-sm font-semibold text-black hover:bg-white/90"
              data-cta="primary"
            >
              Try VibeGauge
            </a>
          </nav>
        </div>
      </header>

      {/* Hero */}
      <section className="relative z-10">
        <div className="mx-auto grid max-w-6xl grid-cols-1 items-center gap-10 px-4 pb-10 pt-6 sm:px-6 sm:pb-14 lg:grid-cols-2 lg:gap-14">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs text-white/70">
              <span className="h-1.5 w-1.5 rounded-full bg-[#7aa7ff] shadow-[0_0_18px_rgba(122,167,255,0.7)]" />
              Conversation insights • Blue → Red vibe gauge
            </div>

            <h1 className="mt-4 text-balance text-4xl font-semibold leading-tight sm:text-5xl">
              Read the room in seconds.
            </h1>

            <p className="mt-4 max-w-xl text-pretty text-base leading-relaxed text-white/75 sm:text-lg">
              VibeGauge-AI analyzes your chats (and conversation screenshots) to surface emotional tone,
              conflict level, and potential red flags — visualized as a color-changing gauge.
              Fast, simple, and privacy-first.
            </p>

            <ul className="mt-6 space-y-2 text-sm text-white/75 sm:text-base">
              <li className="flex gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-white/70" />
                <span>
                  <span className="font-semibold text-white">Instant clarity:</span> See the overall mood and key
                  signals at a glance.
                </span>
              </li>
              <li className="flex gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-white/70" />
                <span>
                  <span className="font-semibold text-white">Spot friction early:</span> Catch escalation, mixed
                  signals, and tension.
                </span>
              </li>
              <li className="flex gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-white/70" />
                <span>
                  <span className="font-semibold text-white">Make calmer moves:</span> Get neutral insights before
                  you reply.
                </span>
              </li>
            </ul>

            <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
              <a
                href={APP_PATH}
                className="inline-flex items-center justify-center rounded-xl bg-white px-5 py-3 text-sm font-semibold text-black hover:bg-white/90 focus:outline-none focus:ring-2 focus:ring-white/40"
                data-cta="primary"
              >
                Try VibeGauge
                <span className="ml-2 text-black/70">→</span>
              </a>

              <a
                href="#waitlist"
                className="inline-flex items-center justify-center rounded-xl border border-white/15 bg-white/5 px-5 py-3 text-sm font-semibold text-white/90 hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-white/25"
                data-cta="secondary"
              >
                Get Early Access / Updates
              </a>

              <div className="text-xs text-white/55 sm:pl-2">
                No Stripe yet — early access updates for now.
              </div>
            </div>

            {/* Tiny instruction bubbles */}
            <div className="mt-8 grid max-w-xl grid-cols-1 gap-3 sm:grid-cols-3">
              {[
                { title: "Paste", body: "Drop in chat text." },
                { title: "Screenshot", body: "Upload convo images." },
                { title: "Gauge", body: "Blue → red mood read." },
              ].map((b) => (
                <div
                  key={b.title}
                  className="rounded-xl border border-white/10 bg-white/5 p-3 text-xs text-white/70"
                >
                  <div className="font-semibold text-white/90">{b.title}</div>
                  <div className="mt-1">{b.body}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Hero Visual: CSS vibe gauge */}
          <div className="relative">
            <div className="mx-auto w-full max-w-md">
              <div className="relative rounded-2xl border border-white/10 bg-white/5 p-6 shadow-[0_0_80px_rgba(120,180,255,0.10)]">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-sm font-semibold">VibeGauge</div>
                    <div className="text-xs text-white/60">blue → red intensity</div>
                  </div>
                  <div className="rounded-full border border-white/10 bg-black/30 px-3 py-1 text-xs text-white/70">
                    Live preview
                  </div>
                </div>

                <div className="mt-6 grid place-items-center">
                  <div className="relative grid h-56 w-56 place-items-center">
                    {/* Ring */}
                    <div
                      className="absolute inset-0 rounded-full p-[10px] shadow-[0_0_50px_rgba(255,80,60,0.10)]"
                      style={{
                        background:
                          "conic-gradient(from 210deg, #4ea1ff 0deg, #7c5cff 70deg, #ff3cb0 140deg, #ff5a3c 240deg, #ff3a3a 300deg, rgba(255,255,255,0.08) 360deg)",
                        animation: "vgPulse 4.5s ease-in-out infinite",
                      }}
                    >
                      <div className="h-full w-full rounded-full bg-[#06070B]" />
                    </div>

                    {/* Inner glow */}
                    <div className="absolute inset-[18px] rounded-full border border-white/10 bg-white/5 shadow-[inset_0_0_40px_rgba(122,167,255,0.18)]" />

                    {/* Needle */}
                    <div className="absolute inset-0 grid place-items-center">
                      <div
                        className="relative h-40 w-40"
                        style={{ animation: "vgNeedle 3.6s ease-in-out infinite" }}
                      >
                        <div className="absolute left-1/2 top-1/2 h-2 w-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow-[0_0_20px_rgba(255,255,255,0.35)]" />
                        <div className="absolute left-1/2 top-1/2 h-1 w-20 -translate-y-1/2 origin-left rounded-full bg-white/80 shadow-[0_0_18px_rgba(255,255,255,0.18)]" />
                      </div>
                    </div>

                    {/* Readout */}
                    <div className="absolute bottom-6 text-center">
                      <div className="text-xs text-white/60">Current vibe</div>
                      <div className="mt-1 text-lg font-semibold tracking-wide">
                        Mixed / Unclear
                      </div>
                      <div className="mt-2 inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/30 px-3 py-1 text-xs text-white/70">
                        <span className="h-2 w-2 rounded-full bg-[#ff3cb0] shadow-[0_0_18px_rgba(255,60,176,0.65)]" />
                        conflict: moderate
                      </div>
                    </div>
                  </div>

                  <div className="mt-6 grid w-full grid-cols-3 gap-2 text-center text-xs text-white/60">
                    <div className="rounded-lg border border-white/10 bg-white/5 py-2">Calm</div>
                    <div className="rounded-lg border border-white/10 bg-white/5 py-2">Tense</div>
                    <div className="rounded-lg border border-white/10 bg-white/5 py-2">Hot</div>
                  </div>

                  <div className="mt-4 text-center text-xs text-white/55">
                    Visual demo only — your real results come from your input.
                  </div>
                </div>

                {/* Scanline */}
                <div
                  aria-hidden="true"
                  className="pointer-events-none absolute inset-0 overflow-hidden rounded-2xl"
                >
                  <div className="scanline absolute -inset-x-10 top-0 h-24 opacity-20" />
                </div>
              </div>
            </div>

            <div className="mt-4 text-center text-xs text-white/55">
              Tip: clearer screenshots = better extraction.
            </div>
          </div>
        </div>
      </section>

      {/* Content sections */}
      <LandingSections appPath={APP_PATH} />

      {/* Waitlist */}
      <section id="waitlist" className="relative z-10 border-t border-white/10">
        <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2 lg:items-center">
            <div>
              <h2 className="text-2xl font-semibold">Get early access updates</h2>
              <p className="mt-2 max-w-xl text-white/70">
                Pricing is coming soon. Join the list to get updates, perks, and early supporter access.
              </p>
              <div className="mt-4 text-xs text-white/55">
                Frontend-only for now: we store your email in your browser (localStorage).
              </div>
            </div>

            <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
              <form onSubmit={onSubmitWaitlist} className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <label className="sr-only" htmlFor="email">
                  Email address
                </label>
                <input
                  id="email"
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder={storedEmail ? storedEmail : "you@domain.com"}
                  className="w-full flex-1 rounded-xl border border-white/10 bg-black/30 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:outline-none focus:ring-2 focus:ring-white/25"
                />
                <button
                  type="submit"
                  className={cn(
                    "rounded-xl px-5 py-3 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-white/25",
                    effectiveState === "saved"
                      ? "bg-white/15 text-white/80 hover:bg-white/20"
                      : "bg-white text-black hover:bg-white/90"
                  )}
                  data-cta="waitlist-submit"
                >
                  {effectiveState === "saved" ? "Saved ✓" : "Join Waitlist"}
                </button>
              </form>

              <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-white/60">
                <a
                  href={mailtoHref}
                  className="underline decoration-white/30 underline-offset-4 hover:text-white"
                  data-cta="waitlist-mailto"
                >
                  Mailto fallback
                </a>
                <span>•</span>
                <button
                  type="button"
                  onClick={() => {
                    try {
                      localStorage.removeItem("vibegauge_waitlist_email");
                      localStorage.removeItem("vibegauge_waitlist_ts");
                    } catch {}
                    setState("idle");
                    setEmail("");
                  }}
                  className="underline decoration-white/30 underline-offset-4 hover:text-white"
                  data-cta="waitlist-clear"
                >
                  Clear
                </button>
              </div>

              {effectiveState === "saved" && (
                <div className="mt-4 rounded-xl border border-white/10 bg-black/30 p-3 text-sm text-white/75">
                  You’re on the list (in this browser). We’ll add a real backend signup soon.
                </div>
              )}
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 border-t border-white/10">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-8 text-xs text-white/55 sm:px-6 sm:flex-row sm:items-center sm:justify-between">
          <div>© {new Date().getFullYear()} VibeGauge-AI / Confusion-AI</div>
          <div className="flex flex-wrap gap-3">
            <a href={APP_PATH} className="hover:text-white" data-cta="footer-try">
              Try the app
            </a>
            <a href="#faq" className="hover:text-white" data-cta="footer-faq">
              FAQ
            </a>
            <span className="text-white/30">Insights, not diagnosis.</span>
          </div>
        </div>
      </footer>
    </main>
  );
}