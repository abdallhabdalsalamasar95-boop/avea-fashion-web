"use client";

import { Check, Copy, Globe2, LoaderCircle, MessageCircle, Share2 } from "lucide-react";
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
  const [menuOpen, setMenuOpen] = useState(false);
  const [shareUrl, setShareUrl] = useState("");
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
      setShareUrl(url);
      setMenuOpen(true);
      setState("idle");
    } catch (reason) {
      if (reason instanceof DOMException && reason.name === "AbortError") {
        setState("idle");
        return;
      }
      setError(reason instanceof Error ? reason.message : "تعذرت المشاركة");
      setState("idle");
    }
  };

  const copy = async () => { await navigator.clipboard.writeText(shareUrl); setState("copied"); window.setTimeout(() => setState("idle"), 2200); };
  const openShare = (url: string) => { window.open(url, "_blank", "noopener,noreferrer"); setMenuOpen(false); };
  return <span className={`ambassador-share-wrap ${compact ? "compact" : ""} ${className}`}>
    <button type="button" className="ambassador-share-button" onClick={share} disabled={state === "loading"} aria-label={label} title={label}>
      {state === "loading" ? <LoaderCircle className="spin" /> : state === "copied" ? <Check /> : <Share2 />}
      {!compact && <span>{state === "copied" ? "تم نسخ الرابط" : state === "loading" ? "جاري تجهيز الرابط..." : label}</span>}
    </button>
    {menuOpen && shareUrl && <span className="share-channel-menu" role="menu" onClick={(event) => event.stopPropagation()}>
      <button type="button" onClick={() => openShare(`https://wa.me/?text=${encodeURIComponent(`${text}\n${shareUrl}`)}`)}><MessageCircle /> واتساب</button>
      <button type="button" onClick={() => openShare(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`)}><Globe2 /> فيسبوك</button>
      <button type="button" onClick={() => openShare(`https://www.messenger.com/t/?link=${encodeURIComponent(shareUrl)}`)}><MessageCircle /> ماسنجر</button>
      <button type="button" onClick={async () => { await copy(); openShare("https://www.instagram.com/"); }}><Globe2 /> إنستغرام</button>
      <button type="button" onClick={copy}><Copy /> {state === "copied" ? "تم النسخ" : "نسخ الرابط"}</button>
    </span>}
    {error && <small>{error}</small>}
  </span>;
}
