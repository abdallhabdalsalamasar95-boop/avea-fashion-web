"use client";

import { Check, LoaderCircle, Share2 } from "lucide-react";
import { useState } from "react";
import { useAuth } from "@/components/auth-provider";
import { useAmbassador } from "@/components/ambassador-context";
import { createAmbassadorShare } from "@/lib/api";

type Props = {
  buildPath: (token: string) => string;
  title: string;
  text: string;
  label?: string;
  className?: string;
  compact?: boolean;
};

export function AmbassadorShareButton({ buildPath, title, text, label = "مشاركة مع الزبونة", className = "", compact = false }: Props) {
  const { user } = useAuth();
  const { ambassador } = useAmbassador();
  const [state, setState] = useState<"idle" | "loading" | "copied">("idle");
  const [error, setError] = useState("");

  const share = async (event: React.MouseEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopPropagation();
    if (state === "loading") return;
    setError("");
    setState("loading");
    try {
      const referral = user && ambassador
        ? await createAmbassadorShare(await user.getIdToken())
        : null;
      const url = new URL(buildPath(referral?.token ?? ""), window.location.origin).toString();
      if (navigator.share) {
        await navigator.share({ title, text, url });
        setState("idle");
      } else {
        await navigator.clipboard.writeText(url);
        setState("copied");
        window.setTimeout(() => setState("idle"), 2200);
      }
    } catch (reason) {
      if (reason instanceof DOMException && reason.name === "AbortError") {
        setState("idle");
        return;
      }
      setError(reason instanceof Error ? reason.message : "تعذرت المشاركة");
      setState("idle");
    }
  };

  return <span className={`ambassador-share-wrap ${compact ? "compact" : ""} ${className}`}>
    <button type="button" className="ambassador-share-button" onClick={share} disabled={state === "loading"} aria-label={label} title={label}>
      {state === "loading" ? <LoaderCircle className="spin" /> : state === "copied" ? <Check /> : <Share2 />}
      {!compact && <span>{state === "copied" ? "تم نسخ الرابط" : state === "loading" ? "جاري تجهيز الرابط..." : label}</span>}
    </button>
    {error && <small>{error}</small>}
  </span>;
}
