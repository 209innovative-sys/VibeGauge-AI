const TOKEN_KEY = "confusionai_pro_token";

export function getProToken(): string | null {
  try { return localStorage.getItem(TOKEN_KEY); } catch { return null; }
}

export function setProToken(token: string) {
  try { localStorage.setItem(TOKEN_KEY, token); } catch {}
}

export function getClientId(): string {
  const key = "confusionai_client_id";
  try {
    let v = localStorage.getItem(key);
    if (!v) {
      v = (crypto?.randomUUID?.() || (Math.random().toString(16).slice(2) + Date.now().toString(16)));
      localStorage.setItem(key, v);
    }
    return v;
  } catch {
    return "anon";
  }
}

export async function startCheckout(apiBase: string): Promise<void> {
  const res = await fetch(${apiBase}/create-checkout-session, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-confusionai-client": getClientId() },
    body: JSON.stringify({})
  });
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  if (!data?.url) throw new Error("No checkout URL returned");
  window.location.href = data.url;
}

export async function completeCheckoutIfPresent(apiBase: string): Promise<"pro" | null> {
  const url = new URL(window.location.href);
  const sessionId = url.searchParams.get("session_id");
  const success = url.searchParams.get("success");
  if (!sessionId || success !== "1") return null;

  const res = await fetch(${apiBase}/verify-session, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-confusionai-client": getClientId() },
    body: JSON.stringify({ session_id: sessionId })
  });
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  if (data?.token) setProToken(data.token);

  // Clean URL
  url.searchParams.delete("session_id");
  url.searchParams.delete("success");
  window.history.replaceState({}, "", url.toString());

  return "pro";
}