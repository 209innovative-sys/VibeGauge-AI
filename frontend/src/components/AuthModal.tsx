import React, { useState } from "react";
import { createUserWithEmailAndPassword, signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "../lib/firebase";

export default function AuthModal({
  open,
  mode,
  onClose,
  onModeChange,
}: {
  open: boolean;
  mode: "login" | "signup";
  onClose: () => void;
  onModeChange: (m: "login" | "signup") => void;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (!open) return null;

  const submit = async () => {
    setErr(null);
    setBusy(true);
    try {
      if (mode === "signup") {
        await createUserWithEmailAndPassword(auth, email.trim(), password);
      } else {
        await signInWithEmailAndPassword(auth, email.trim(), password);
      }
      onClose();
    } catch (e: any) {
      setErr(e?.message ?? "Auth failed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-950 p-4">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-slate-100">
            {mode === "signup" ? "Create account" : "Log in"}
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-slate-700 bg-slate-900/50 px-2 py-1 text-xs text-slate-200 hover:bg-slate-800/60"
          >
            Close
          </button>
        </div>

        {err && (
          <div className="mt-3 rounded-xl border border-red-500/30 bg-red-500/10 p-2 text-xs text-red-200">
            {err}
          </div>
        )}

        <div className="mt-3 space-y-2">
          <input
            className="w-full rounded-xl border border-slate-700 bg-slate-900/40 px-3 py-2 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-cyan-500/40"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
          />
          <input
            className="w-full rounded-xl border border-slate-700 bg-slate-900/40 px-3 py-2 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-cyan-500/40"
            placeholder="Password (6+ chars)"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete={mode === "signup" ? "new-password" : "current-password"}
          />
        </div>

        <button
          type="button"
          onClick={submit}
          disabled={busy || !email.trim() || password.length < 6}
          className="mt-3 w-full rounded-xl bg-emerald-500 px-4 py-2 text-xs font-bold text-slate-950 hover:bg-emerald-400 disabled:opacity-60"
        >
          {busy ? "Please wait..." : mode === "signup" ? "Sign up" : "Log in"}
        </button>

        <div className="mt-3 flex items-center justify-between text-[11px] text-slate-400">
          <span>{mode === "signup" ? "Already have an account?" : "Need an account?"}</span>
          <button
            type="button"
            onClick={() => onModeChange(mode === "signup" ? "login" : "signup")}
            className="font-semibold text-cyan-300 hover:text-cyan-200"
          >
            {mode === "signup" ? "Log in" : "Sign up"}
          </button>
        </div>
      </div>
    </div>
  );
}