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

  useEffect(() => {
    setMounted(true);

    const standalone =
      window.matchMedia("(display-mode: standalone)").matches ||
      ("standalone" in window.navigator && (window.navigator as any).standalone === true);

    setIsStandalone(standalone);
    setBrowserLabel(detectBrowserLabel());

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
      ? 'في Safari: اضغطي زر المشاركة ثم اختاري "إضافة إلى الشاشة الرئيسية".'
      : browserLabel === "Firefox"
        ? 'في Firefox: افتحي قائمة المتصفح وابحثي عن "Install" أو "Add to Home Screen".'
        : 'في هذا المتصفح: افتحي قائمة المتصفح وابحثي عن "Install app" أو "Add to Home Screen".';

  return (
    <>
      <button
        onClick={handleInstall}
        aria-label="حملي تطبيق افيا"
        style={{
          position: "fixed",
          top: 96,
          left: 16,
          zIndex: 9999,
          border: 0,
          borderRadius: 999,
          padding: "10px 14px",
          background: "rgba(15, 23, 42, 0.94)",
          color: "#fff",
          boxShadow: "0 14px 32px rgba(15, 23, 42, 0.18)",
          display: "inline-flex",
          alignItems: "center",
          gap: 8,
          direction: "rtl",
          fontWeight: 800,
          fontSize: 13,
          letterSpacing: "0.1px",
          cursor: "pointer",
          backdropFilter: "blur(10px)",
          whiteSpace: "nowrap",
        }}
      >
        <span aria-hidden="true">⬇</span>
        <span>حملي تطبيق افيا</span>
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
              حملي تطبيق افيا
            </strong>

            <p style={{ margin: "0 0 12px", color: "#75696e", lineHeight: 1.8, fontSize: 13 }}>
              {deferredPrompt
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