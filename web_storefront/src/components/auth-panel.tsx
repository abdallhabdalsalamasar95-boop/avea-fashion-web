"use client";

import { FirebaseError } from "firebase/app";
import { Check, Eye, EyeOff, Lock, LogOut, Mail, Sparkles, UserRound } from "lucide-react";
import { FormEvent, useState } from "react";
import { useAuth } from "@/components/auth-provider";

const messages: Record<string, string> = {
  "auth/invalid-credential": "البريد الإلكتروني / رقم الهاتف أو كلمة المرور غير صحيحة.",
  "auth/wrong-password": "كلمة المرور غير صحيحة.",
  "auth/user-not-found": "لا يوجد حساب بهذا البريد أو الرقم.",
  "auth/email-already-in-use": "يوجد حساب مسجل بهذا البريد أو الرقم بالفعل.",
  "auth/weak-password": "كلمة المرور ضعيفة. استخدمي 6 أحرف أو أرقام على الأقل.",
  "auth/popup-closed-by-user": "تم إغلاق نافذة الدخول بواسطة Google.",
  "auth/invalid-email": "صيغة البريد الإلكتروني أو رقم الهاتف غير صحيحة.",
  "auth/network-request-failed": "تعذر الاتصال بالشبكة. يرجى التأكد من اتصال الإنترنت والمحاولة مجددًا.",
  "auth/too-many-requests": "تم حظر المحاولات مؤقتًا لكثرة المحاولات الخاطئة. يرجى الانتظار قليلًا.",
};

function normalizeIdentifier(raw: string): string {
  const clean = raw.trim();
  if (!clean) return "";
  if (clean.includes("@")) return clean.toLowerCase();
  const digitsOnly = clean.replace(/\D/g, "");
  if (digitsOnly.length >= 9) {
    return `${digitsOnly}@carmenkarla.ly`;
  }
  return clean;
}

interface AuthPanelProps {
  onSuccess?: () => void;
  title?: string;
  subtitle?: string;
}

export function AuthPanel({ onSuccess, title, subtitle }: AuthPanelProps = {}) {
  const { user, loading, login, register, google, resetPassword, logout } = useAuth();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [mode, setMode] = useState<"login" | "register" | "forgot">("login");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [successMessage, setSuccessMessage] = useState("");

  const run = async (action: () => Promise<void>, success = "") => {
    setBusy(true);
    setMessage("");
    setSuccessMessage("");
    try {
      await action();
      if (success) setSuccessMessage(success);
      onSuccess?.();
    } catch (error) {
      const code = error instanceof FirebaseError ? error.code : "";
      setMessage(messages[code] || "تعذر إتمام العملية. تحققي من البيانات وحاولي مجددًا.");
    } finally {
      setBusy(false);
    }
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    const cleanId = normalizeIdentifier(identifier);
    if (!cleanId) {
      setMessage("يرجى إدخال البريد الإلكتروني أو رقم الهاتف.");
      return;
    }
    if (mode === "forgot") {
      if (!cleanId.includes("@")) {
        setMessage("يرجى إدخال بريدكِ الإلكتروني المسجل لإرسال رابط الاستعادة.");
        return;
      }
      void run(
        () => resetPassword(cleanId),
        "تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني بنجاح. تفقدي الوارد والرسائل غير المرغوب فيها."
      );
      return;
    }
    if (!password || password.length < 6) {
      setMessage("كلمة المرور يجب أن لا تقل عن 6 خانات.");
      return;
    }
    void run(async () => {
      if (mode === "login") {
        await login(cleanId, password);
      } else {
        await register(cleanId, password);
      }
    });
  };

  if (loading) return <div className="auth-loading">جاري التحقق من الحساب...</div>;

  if (user) {
    return (
      <div className="signed-user">
        <div className="signed-user-info">
          <UserRound />
          <span>
            <small>تم تسجيل الدخول</small>
            <strong>{user.displayName || user.email?.replace(/@carmenkarla\.ly$/, "") || user.email}</strong>
          </span>
        </div>
        <button className="logout-btn" onClick={() => void logout()}>
          <LogOut /> تسجيل الخروج
        </button>
      </div>
    );
  }

  return (
    <div className="auth-panel">
      <div className="auth-intro">
        <Sparkles />
        <span>
          <small>{title || "مساحتك الخاصة"}</small>
          <h2>
            {mode === "login"
              ? "تسجيل الدخول"
              : mode === "register"
              ? "إنشاء حساب جديد"
              : "استعادة كلمة المرور"}
          </h2>
          <p>{subtitle || "احتفظي بطلباتك ومفضلاتك وتتبعي شحناتك بسهولة."}</p>
        </span>
      </div>

      <div className="auth-tabs">
        <button
          type="button"
          className={mode === "login" ? "auth-tab active" : "auth-tab"}
          onClick={() => { setMode("login"); setMessage(""); setSuccessMessage(""); }}
        >
          تسجيل الدخول
        </button>
        <button
          type="button"
          className={mode === "register" ? "auth-tab active" : "auth-tab"}
          onClick={() => { setMode("register"); setMessage(""); setSuccessMessage(""); }}
        >
          حساب جديد
        </button>
      </div>

      <form onSubmit={submit} className="auth-form">
        <div className="auth-input-group">
          <Mail className="input-icon" />
          <input
            required
            type="text"
            dir="ltr"
            autoComplete="username"
            placeholder="البريد الإلكتروني أو رقم الهاتف"
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
          />
        </div>

        {mode !== "forgot" && (
          <div className="auth-input-group">
            <Lock className="input-icon" />
            <input
              required
              minLength={6}
              type={showPassword ? "text" : "password"}
              dir="ltr"
              autoComplete={mode === "login" ? "current-password" : "new-password"}
              placeholder="كلمة المرور"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <button
              type="button"
              className="toggle-password-btn"
              onClick={() => setShowPassword(!showPassword)}
              aria-label={showPassword ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"}
            >
              {showPassword ? <EyeOff /> : <Eye />}
            </button>
          </div>
        )}

        {mode === "login" && (
          <div className="auth-options-row">
            <label className="remember-checkbox">
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
              />
              <span>تذكرني</span>
            </label>
            <button
              type="button"
              className="forgot-link"
              onClick={() => { setMode("forgot"); setMessage(""); setSuccessMessage(""); }}
            >
              نسيت كلمة المرور؟
            </button>
          </div>
        )}

        <button className="primary-button auth-submit-btn" disabled={busy}>
          {busy
            ? "يرجى الانتظار..."
            : mode === "login"
            ? "دخول"
            : mode === "register"
            ? "إنشاء الحساب"
            : "إرسال رابط الاستعادة"}
        </button>
      </form>

      {mode !== "forgot" && (
        <button
          className="google-button"
          disabled={busy}
          onClick={() => void run(google)}
        >
          <span className="google-icon">G</span> المتابعة باستخدام Google
        </button>
      )}

      {message && <div className="auth-message error">{message}</div>}
      {successMessage && <div className="auth-message success"><Check /> {successMessage}</div>}

      {mode === "forgot" && (
        <div className="auth-links">
          <button
            type="button"
            disabled={busy}
            onClick={() => { setMode("login"); setMessage(""); setSuccessMessage(""); }}
          >
            العودة لتسجيل الدخول
          </button>
        </div>
      )}
    </div>
  );
}
