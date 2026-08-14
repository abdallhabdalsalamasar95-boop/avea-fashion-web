"use client";

import { Camera, Globe, MessageCircle, Music2, Send, Share2 } from "lucide-react";
import { useEffect, useState } from "react";
import { fetchAppContent } from "@/lib/api";

type SocialLinksConfig = {
  enabled?: boolean;
  instagram?: string;
  facebook?: string;
  whatsapp?: string;
  telegram?: string;
  tiktok?: string;
  website?: string;
};

const items = [
  { key: "instagram", label: "Instagram", Icon: Camera },
  { key: "facebook", label: "Facebook", Icon: Share2 },
  { key: "whatsapp", label: "WhatsApp", Icon: MessageCircle },
  { key: "telegram", label: "Telegram", Icon: Send },
  { key: "tiktok", label: "TikTok", Icon: Music2 },
  { key: "website", label: "الموقع", Icon: Globe },
] as const;

export function SocialLinks() {
  const [links, setLinks] = useState<SocialLinksConfig>({});

  useEffect(() => {
    const controller = new AbortController();
    fetchAppContent(controller.signal)
      .then((content) => setLinks((content as { websiteSocial?: SocialLinksConfig }).websiteSocial ?? {}))
      .catch(() => setLinks({}))
      .finally(() => controller.signal.aborted || undefined);
    return () => controller.abort();
  }, []);

  const visible = items.filter(({ key }) => Boolean(links[key]));
  if (links.enabled === false || visible.length === 0) return null;

  return (
    <section className="social-links" aria-label="تابعينا وشاركي صفحاتنا">
      <span>تابعينا وشاركي صفحاتنا</span>
      <div>
        {visible.map(({ key, label, Icon }) => <a href={links[key]} target="_blank" rel="noreferrer" key={key} aria-label={label} title={label}><Icon /><span>{label}</span></a>)}
      </div>
    </section>
  );
}

