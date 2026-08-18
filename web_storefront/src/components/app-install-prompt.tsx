"use client";

import { useEffect, useState } from "react";

declare global {
  interface BeforeInstallPromptEvent extends Event {
    readonly platforms: string[];
    prompt: () => Promise<void>;
    userChoice: Promise<{ outcome: "accepted" | "dismissed"; platform: string }>;
  }
}

type BrowserLabel = "Chrome" | "Edge" | "Firefox" | "Safari" | "المتصفح";
const ANDROID_APK_URL = "https://avea-fashion-web.onrender.com/avea-fashion.apk";

function detectBrowserLabel(): BrowserLabel {
  const ua = window.navigator.userAgent.toLowerCase();

  if (ua.includes("iphone") || ua.includes("ipad") || ua.includes("ipod")) return "Safari";
  if (ua.includes("edg/")) return "Edge";
  if (ua.includes("firefox/")) return "Firefox";
  if (ua.includes("chrome/")) return "Chrome";

  return "المتصفح";
}

export function AppInstallPrompt() {
  const [mounted, setMounted] = useState(false);
  const [isStandalone, setIsStandalone] = useState(false);
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [showHelp, setShowHelp] = useState(false);
  const [browserLabel, setBrowserLabel] = useState<BrowserLabel>("المتصفح");
  const [isAndroid, setIsAndroid] = useState(false);

  useEffect(() => {
    setMounted(true);

    const standalone =
      window.matchMedia("(display-mode: standalone)").matches ||
      ("standalone" in window.navigator && (window.navigator as any).standalone === true);

    setIsStandalone(standalone);
    setBrowserLabel(detectBrowserLabel());
    setIsAndroid(/android/i.test(window.navigator.userAgent));

    const onBeforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      setDeferredPrompt(event as BeforeInstallPromptEvent);
    };

    const onAppInstalled = () => {
      setIsStandalone(true);
      setDeferredPrompt(null);
      setShowHelp(false);
    };

    window.addEventListener("beforeinstallprompt", onBeforeInstallPrompt);
    window.addEventListener("appinstalled", onAppInstalled);

    return () => {
      window.removeEventListener("beforeinstallprompt", onBeforeInstallPrompt);
      window.removeEventListener("appinstalled", onAppInstalled);
    };
  }, []);

  if (!mounted || isStandalone) return null;

  const handleInstall = async () => {
    if (isAndroid) {
      const chromeIntent = "intent://avea-fashion-web.onrender.com/avea-fashion.apk#Intent;scheme=https;package=com.android.chrome;end";
      window.location.href = chromeIntent;
      return;
    }
    if (!deferredPrompt) {
      setShowHelp(true);
      return;
    }

    await deferredPrompt.prompt();
    const choice = await deferredPrompt.userChoice;
    setDeferredPrompt(null);
    setShowHelp(choice.outcome !== "accepted");
  };

  const helpText =
    browserLabel === "Safari"
      ? 'في Safari: اضغطي زر المشاركة ثم اختاري "إضافة إلى الشاشة الرئيسية"، وبعدها اضغطي "إضافة".'
      : browserLabel === "Firefox"
        ? 'في Firefox: افتحي قائمة المتصفح وابحثي عن "Install" أو "Add to Home Screen".'
        : 'في هذا المتصفح: افتحي قائمة المتصفح وابحثي عن "Install app" أو "Add to Home Screen".';

  return (
    <>
      <button
        className="app-install-prompt"
        onClick={handleInstall}
        aria-label="حمّلي تطبيق AVEA"
        style={{
          position: "relative",
          zIndex: 51,
          border: "1px solid rgba(77, 29, 47, .16)",
          borderRadius: 7,
          width: 58,
          minWidth: 58,
          height: 26,
          padding: 0,
          background: "#fff",
          color: "#4d1d2f",
          boxShadow: "0 2px 7px rgba(77, 29, 47, .12)",
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 3,
          direction: "rtl",
          cursor: "pointer",
          backdropFilter: "blur(10px)",
        }}
      >
        <span aria-hidden="true" style={{ width: 17, height: 17, display: "grid", placeItems: "center", borderRadius: 5, background: "#4d1d2f", color: "#fff", fontFamily: "Georgia, serif", fontSize: 10, letterSpacing: 1 }}>A</span>
        <span style={{ fontSize: 7, lineHeight: 1, whiteSpace: "nowrap" }}>تطبيق AVEA</span>
      </button>

      {showHelp && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="طريقة تثبيت التطبيق"
          style={{
            position: "fixed",
            inset: 0,
            zIndex: 10000,
            background: "rgba(15, 23, 42, 0.42)",
            display: "grid",
            placeItems: "end start",
            padding: 16,
          }}
          onClick={() => setShowHelp(false)}
        >
          <div
            style={{
              width: "min(100%, 320px)",
              borderRadius: 18,
              background: "#fff",
              color: "#211a1d",
              boxShadow: "0 24px 60px rgba(15, 23, 42, 0.25)",
              padding: 16,
              direction: "rtl",
            }}
            onClick={(event) => event.stopPropagation()}
          >
            <strong style={{ display: "block", marginBottom: 8, fontSize: 15 }}>
              {isAndroid ? "حمّلي تطبيق AVEA" : "أضيفي AVEA للشاشة الرئيسية"}
            </strong>

            <p style={{ margin: "0 0 12px", color: "#75696e", lineHeight: 1.8, fontSize: 13 }}>
              {isAndroid
                ? "سيبدأ تنزيل تطبيق AVEA بصيغة APK. بعد اكتمال التنزيل افتحي الملف ووافقي على التثبيت."
                : deferredPrompt
                ? "إذا ظهر مربع التثبيت، وافقي عليه وسيتم التثبيت مباشرة."
                : helpText}
            </p>

            <button
              type="button"
              onClick={() => setShowHelp(false)}
              style={{
                border: 0,
                borderRadius: 12,
                padding: "10px 14px",
                background: "#0f172a",
                color: "#fff",
                fontWeight: 800,
                cursor: "pointer",
              }}
            >
              فهمت
            </button>
          </div>
        </div>
      )}
    </>
  );
}