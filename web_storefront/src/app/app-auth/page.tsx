"use client";

import { GoogleAuthProvider, signInWithPopup, signInWithRedirect, getRedirectResult } from "firebase/auth";
import { useCallback, useEffect, useState } from "react";
import { auth } from "@/lib/firebase";

const APP_SCHEME = "carmenkarla://auth";

type Stage = "idle" | "working" | "handoff" | "error";

/**
 * Bridge for the Android app: signs in with Google on the web (where the OAuth
 * client already exists) and hands the resulting Google ID token back over a
 * custom scheme, so the app needs no native OAuth registration.
 */
export default function AppAuthPage() {
  const [stage, setStage] = useState<Stage>("idle");
  const [error, setError] = useState("");
  const [handoffUrl, setHandoffUrl] = useState("");

  const handoff = useCallback((idToken: string) => {
    const url = `${APP_SCHEME}?idToken=${encodeURIComponent(idToken)}`;
    setHandoffUrl(url);
    setStage("handoff");
    window.location.href = url;
  }, []);

  const start = useCallback(async () => {
    setError("");
    setStage("working");
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: "select_account" });
    try {
      const result = await signInWithPopup(auth, provider);
      const idToken = GoogleAuthProvider.credentialFromResult(result)?.idToken;
      if (!idToken) throw new Error("تعذر الحصول على بيانات الحساب");
      handoff(idToken);
    } catch (reason) {
      const code = (reason as { code?: string }).code ?? "";
      if (code === "auth/popup-blocked" || code === "auth/operation-not-supported-in-this-environment") {
        await signInWithRedirect(auth, provider);
        return;
      }
      setError((reason as Error).message || "تعذر تسجيل الدخول");
      setStage("error");
    }
  }, [handoff]);

  useEffect(() => {
    void getRedirectResult(auth)
      .then((result) => {
        if (!result) return;
        const idToken = GoogleAuthProvider.credentialFromResult(result)?.idToken;
        if (idToken) handoff(idToken);
      })
      .catch(() => undefined);
  }, [handoff]);

  return (
    <section
      style={{
        minHeight: "70vh",
        display: "grid",
        placeItems: "center",
        padding: "24px",
        textAlign: "center",
      }}
    >
      <div style={{ maxWidth: 380, display: "grid", gap: 14 }}>
        <strong style={{ fontSize: 22 }}>تسجيل الدخول إلى تطبيق كارمن كارلا</strong>
        <p style={{ color: "var(--muted)", margin: 0, fontSize: 14, lineHeight: 1.7 }}>
          سجّلي الدخول بحساب Google وسنعيدك إلى التطبيق تلقائيًا.
        </p>

        {stage === "handoff" ? (
          <>
            <p style={{ color: "var(--rose-dark)", margin: 0, fontSize: 14 }}>
              جارٍ العودة إلى التطبيق...
            </p>
            <a
              href={handoffUrl}
              style={{
                background: "var(--ink)",
                color: "#fff",
                padding: "13px 18px",
                borderRadius: 8,
                fontWeight: 600,
              }}
            >
              فتح التطبيق
            </a>
          </>
        ) : (
          <button
            type="button"
            onClick={() => void start()}
            disabled={stage === "working"}
            style={{
              background: "var(--ink)",
              color: "#fff",
              border: "none",
              padding: "14px 18px",
              borderRadius: 8,
              fontWeight: 600,
            }}
          >
            {stage === "working" ? "جارٍ الفتح..." : "المتابعة بحساب Google"}
          </button>
        )}

        {error ? (
          <p style={{ color: "#c0392b", margin: 0, fontSize: 13 }}>{error}</p>
        ) : null}
      </div>
    </section>
  );
}
