"use client";

import { FirebaseError } from "firebase/app";
import { LogOut, Mail, UserRound } from "lucide-react";
import { FormEvent, useState } from "react";
import { useAuth } from "@/components/auth-provider";

const messages: Record<string, string> = {
  "auth/invalid-credential": "البريد أو كلمة المرور غير صحيحة.",
  "auth/email-already-in-use": "يوجد حساب بهذا البريد بالفعل.",
  "auth/weak-password": "استخدمي كلمة مرور من 6 أحرف على الأقل.",
  "auth/popup-closed-by-user": "أُغلقت نافذة تسجيل Google.",
};

export function AuthPanel() {
  const { user, loading, login, register, google, resetPassword, logout } = useAuth();
  const [email, setEmail] = useState(""); const [password, setPassword] = useState("");
  const [mode, setMode] = useState<"login" | "register">("register");
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState("");
  const run = async (action: () => Promise<void>, success = "") => { setBusy(true); setMessage(""); try { await action(); setMessage(success); } catch (error) { const code = error instanceof FirebaseError ? error.code : ""; setMessage(messages[code] || "تعذر إتمام العملية. تحققي من البيانات وحاولي مجددًا."); } finally { setBusy(false); } };
  const submit = (event: FormEvent) => { event.preventDefault(); void run(() => mode === "login" ? login(email, password) : register(email, password)); };
  if (loading) return <div className="auth-loading">جاري التحقق من الحساب...</div>;
  if (user) return <div className="signed-user"><div><UserRound /><span><small>تم تسجيل الدخول</small><strong>{user.displayName || user.email}</strong></span></div><button onClick={() => void logout()}><LogOut /> تسجيل الخروج</button></div>;
  return <div className="auth-panel"><div className="auth-intro"><Mail /><span><small>مزامنة آمنة</small><h2>{mode === "login" ? "تسجيل الدخول" : "إنشاء حساب جديد"}</h2><p>احتفظي بمفضلاتك وطلباتك على جميع أجهزتك.</p></span></div><form onSubmit={submit}><input required type="email" dir="ltr" placeholder="البريد الإلكتروني" value={email} onChange={(e) => setEmail(e.target.value)} /><input required minLength={6} type="password" dir="ltr" placeholder="كلمة المرور" value={password} onChange={(e) => setPassword(e.target.value)} /><button className="primary-button" disabled={busy}>{busy ? "يرجى الانتظار..." : mode === "login" ? "دخول" : "إنشاء الحساب"}</button></form><button className="google-button" onClick={() => void run(google)}>G&nbsp;&nbsp; المتابعة باستخدام Google</button>{message && <p className="auth-message">{message}</p>}<div className="auth-links"><button onClick={() => setMode(mode === "login" ? "register" : "login")}>{mode === "login" ? "ليس لديك حساب؟ أنشئي حسابًا" : "لديك حساب؟ سجّلي الدخول"}</button>{mode === "login" && <button onClick={() => email ? void run(() => resetPassword(email), "تم إرسال رابط استعادة كلمة المرور.") : setMessage("أدخلي البريد الإلكتروني أولًا.")}>نسيت كلمة المرور</button>}</div></div>;
}
