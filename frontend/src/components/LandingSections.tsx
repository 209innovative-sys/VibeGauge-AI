import React from "react";

function SectionHeader(props: { kicker?: string; title: string; subtitle?: string }) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      {props.kicker && (
        <div className="text-xs font-semibold tracking-wide text-white/60">{props.kicker}</div>
      )}
      <h2 className="mt-2 text-2xl font-semibold sm:text-3xl">{props.title}</h2>
      {props.subtitle && <p className="mt-3 text-white/70">{props.subtitle}</p>}
    </div>
  );
}

function Card(props: { title: string; body: string; icon?: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
      <div className="flex items-start gap-3">
        <div className="grid h-10 w-10 place-items-center rounded-xl border border-white/10 bg-black/30">
          {props.icon || <span className="h-2.5 w-2.5 rounded-full bg-white/70" />}
        </div>
        <div>
          <div className="text-base font-semibold">{props.title}</div>
          <p className="mt-2 text-sm leading-relaxed text-white/70">{props.body}</p>
        </div>
      </div>
    </div>
  );
}

function FAQItem(props: { q: string; a: string }) {
  return (
    <details className="group rounded-2xl border border-white/10 bg-white/5 p-5">
      <summary className="cursor-pointer list-none text-sm font-semibold text-white/90">
        <span className="inline-flex items-center justify-between gap-3">
          {props.q}
          <span className="ml-auto text-white/50 group-open:rotate-45 transition-transform">+</span>
        </span>
      </summary>
      <p className="mt-3 text-sm leading-relaxed text-white/70">{props.a}</p>
    </details>
  );
}

export function LandingSections({ appPath }: { appPath: string }) {
  return (
    <>
      {/* Trust strip */}
      <section className="relative z-10 border-t border-white/10">
        <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            {[
              { t: "Privacy-first by default", d: "Built to minimize retention and keep things simple." },
              { t: "Fast, clear output", d: "Gauge + bullets. No walls of text." },
              { t: "No creepy vibes", d: "Insights from what you provide — not surveillance." },
            ].map((x) => (
              <div key={x.t} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <div className="text-sm font-semibold">{x.t}</div>
                <div className="mt-1 text-xs text-white/65">{x.d}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Benefits */}
      <section className="relative z-10">
        <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
          <SectionHeader
            kicker="What you get"
            title="Conversation insights that are easy to understand"
            subtitle="A quick vibe read plus a clean breakdown of what might be happening — without overcomplicating it."
          />

          <div className="mt-10 grid grid-cols-1 gap-4 md:grid-cols-3">
            <Card
              title="Tone & mood signals"
              body="Get a simple read on emotional tone and intensity so you can respond with more control."
            />
            <Card
              title="Conflict & escalation"
              body="See potential friction points, tension spikes, and where the conversation heats up."
            />
            <Card
              title="Red flag prompts"
              body="Surface patterns that may be worth a second look — without claiming certainty."
            />
          </div>

          <div className="mt-10 flex justify-center">
            <a
              href={appPath}
              className="inline-flex items-center justify-center rounded-xl bg-white px-5 py-3 text-sm font-semibold text-black hover:bg-white/90 focus:outline-none focus:ring-2 focus:ring-white/40"
              data-cta="mid-primary"
            >
              Try VibeGauge
              <span className="ml-2 text-black/70">→</span>
            </a>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="relative z-10 border-t border-white/10">
        <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
          <SectionHeader
            kicker="How it works"
            title="Three steps to a clean vibe check"
            subtitle="Paste text or upload a screenshot. Tap analyze. Read the gauge + the key takeaways."
          />

          <div className="mt-10 grid grid-cols-1 gap-4 md:grid-cols-4">
            {[
              { n: "1", t: "Paste or upload", d: "Text conversation or screenshot." },
              { n: "2", t: "Analyze", d: "We extract signals from the content you provide." },
              { n: "3", t: "View your gauge", d: "Blue → red mood intensity at a glance." },
              { n: "4", t: "Use it wisely", d: "Second opinion before you reply." },
            ].map((s) => (
              <div key={s.n} className="relative rounded-2xl border border-white/10 bg-white/5 p-6">
                <div className="absolute right-4 top-4 rounded-full border border-white/10 bg-black/30 px-2 py-0.5 text-xs text-white/60">
                  Step {s.n}
                </div>
                <div className="text-base font-semibold">{s.t}</div>
                <div className="mt-2 text-sm text-white/70">{s.d}</div>
              </div>
            ))}
          </div>

          <div className="mt-8 rounded-2xl border border-white/10 bg-black/30 p-5 text-sm text-white/75">
            <span className="font-semibold text-white">Screenshot note:</span> clearer images = better extraction. If the
            screenshot is cropped, blurry, or has overlays, results may be limited.
          </div>
        </div>
      </section>

      {/* Who it's for + safety */}
      <section className="relative z-10 border-t border-white/10">
        <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
          <div className="grid grid-cols-1 gap-10 lg:grid-cols-2 lg:gap-14">
            <div>
              <h3 className="text-xl font-semibold">Who it’s for</h3>
              <ul className="mt-4 space-y-2 text-sm text-white/75">
                {[
                  "People navigating confusing conversations (dating, friends, family, work)",
                  "Anyone who wants a quick “vibe check” before replying",
                  "Creators, community managers, and teams moderating tone & conflict",
                  "Curious minds who like patterns, not drama",
                ].map((x) => (
                  <li key={x} className="flex gap-3">
                    <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-white/70" />
                    <span>{x}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
              <h3 className="text-xl font-semibold">Trust & safety</h3>
              <p className="mt-3 text-sm leading-relaxed text-white/70">
                Built to be helpful, not invasive. VibeGauge-AI gives lightweight insights from the text you provide.
                It’s not therapy, not surveillance, and not a lie detector. Use it as a second opinion — context and
                nuance matter.
              </p>
              <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
                {[
                  { t: "No diagnosis claims", d: "Insights only — not medical/legal advice." },
                  { t: "No creep factor", d: "No stalking, no profiling — just your input." },
                ].map((x) => (
                  <div key={x.t} className="rounded-xl border border-white/10 bg-black/30 p-4">
                    <div className="text-sm font-semibold">{x.t}</div>
                    <div className="mt-1 text-xs text-white/65">{x.d}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="relative z-10 border-t border-white/10">
        <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
          <SectionHeader
            kicker="FAQ"
            title="Common questions"
            subtitle="Quick answers so you know what to expect."
          />

          <div className="mt-10 grid grid-cols-1 gap-3 lg:grid-cols-2">
            <FAQItem
              q="Does it support screenshots of conversations?"
              a="Yes — you can analyze screenshots (DMs, texts, app chats). Results depend on image clarity and visible text."
            />
            <FAQItem
              q="How accurate is it?"
              a="It’s an AI model making best-effort predictions from the content provided. Use it as a second opinion — sarcasm, missing context, and inside jokes can affect results."
            />
            <FAQItem
              q="Is my data stored?"
              a="This landing page stores waitlist emails only in your browser (localStorage). The analysis flow depends on your current app setup — the goal is privacy-first and minimal retention."
            />
            <FAQItem
              q="Do I need an account?"
              a="Not for early access updates. The app flow should stay simple; accounts may be optional later for saving history or settings."
            />
            <FAQItem
              q="What kind of insights do I get?"
              a="Tone/mood signals, conflict/escalation level, possible red flags, and a short summary — visualized as a color-changing gauge with clear bullets."
            />
            <FAQItem
              q="Is this professional advice or a diagnosis?"
              a="No. This is informational and meant for reflection. It does not provide medical, legal, or therapeutic advice."
            />
            <FAQItem
              q="How much will it cost?"
              a="Pricing is coming soon. You’ll be able to try the core experience, with optional paid upgrades later (early supporters get perks)."
            />
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="relative z-10 border-t border-white/10">
        <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
          <div className="rounded-3xl border border-white/10 bg-white/5 p-8 text-center sm:p-10">
            <h2 className="text-2xl font-semibold sm:text-3xl">Ready for a clean vibe check?</h2>
            <p className="mx-auto mt-3 max-w-2xl text-white/70">
              Jump into the app, run an analysis, and see the gauge shift from blue to red based on the conversation.
            </p>

            <div className="mt-7 flex flex-col justify-center gap-3 sm:flex-row">
              <a
                href={appPath}
                className="inline-flex items-center justify-center rounded-xl bg-white px-6 py-3 text-sm font-semibold text-black hover:bg-white/90 focus:outline-none focus:ring-2 focus:ring-white/40"
                data-cta="final-primary"
              >
                Try VibeGauge
                <span className="ml-2 text-black/70">→</span>
              </a>
              <a
                href="#waitlist"
                className="inline-flex items-center justify-center rounded-xl border border-white/15 bg-black/30 px-6 py-3 text-sm font-semibold text-white/90 hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-white/25"
                data-cta="final-secondary"
              >
                Get Early Access / Updates
              </a>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}