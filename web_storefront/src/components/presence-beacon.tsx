"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { API_BASE_URL } from "@/lib/api";
import { useAuth } from "@/components/auth-provider";

const SESSION_KEY = "carmenkarla.presence.sid";
const INTERVAL_MS = 30_000;

const screenLabel = (path: string): string => {
  const first = path.split("/").filter(Boolean)[0] ?? "";
  if (!first) return "الرئيسية";
  return ({
    product: "منتج",
    category: "قسم",
    cart: "السلة",
    checkout: "إتمام الطلب",
    account: "حسابي",
    favorites: "المفضلة",
    ambassador: "المندوبات",
  } as Record<string, string>)[first] ?? first;
};

/** Heartbeat so the admin can see live visitors; stops when the admin disables tracking. */
export function PresenceBeacon() {
  const { user } = useAuth();
  const pathname = usePathname();

  useEffect(() => {
    let sid = sessionStorage.getItem(SESSION_KEY);
    if (!sid) {
      sid = crypto.randomUUID();
      sessionStorage.setItem(SESSION_KEY, sid);
    }

    let stopped = false;
    let timer = 0;

    const ping = async () => {
      if (stopped || document.visibilityState !== "visible") return;
      try {
        const response = await fetch(`${API_BASE_URL}/presence/ping`, {
          method: "POST",
          keepalive: true,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            sid,
            platform: "web",
            uid: user?.uid ?? "",
            name: user?.displayName || user?.email || "",
            screen: screenLabel(pathname ?? "/"),
          }),
        });
        const payload = await response.json().catch(() => null);
        if (payload && payload.enabled === false) {
          stopped = true;
          window.clearInterval(timer);
        }
      } catch {
        // A missed heartbeat is never worth surfacing to the shopper.
      }
    };

    void ping();
    timer = window.setInterval(() => void ping(), INTERVAL_MS);
    const onVisible = () => void ping();
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      stopped = true;
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [user, pathname]);

  return null;
}
