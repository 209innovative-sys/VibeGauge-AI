export function saveWaitlistEmail(email: string) {
  try {
    const list = JSON.parse(localStorage.getItem("confusionai_waitlist") || "[]");
    list.push({ email, date: new Date().toISOString() });
    localStorage.setItem("confusionai_waitlist", JSON.stringify(list));
    return true;
  } catch {
    return false;
  }
}
