"use client";

import { useEffect } from "react";
import { API_BASE_URL } from "@/lib/api";

const SESSION_KEY = "carmenkarla.presence.sid";
const INTERVAL_MS = 30_000;

/** Sends an anonymous "someone is browsing" heartbeat so the admin can see live visitors. */
export function PresenceBeacon() {
  useEffect(() => {
    let sid = sessionStorage.getItem(SESSION_KEY);
    if (!sid) {
      sid = crypto.randomUUID();
      sessionStorage.setItem(SESSION_KEY, sid);
    }

    const ping = () => {
      if (document.visibilityState !== "visible") return;
      void fetch(`${API_BASE_URL}/presence/ping`, {
        method: "POST",
        keepalive: true,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sid, platform: "web" }),
      }).catch(() => undefined);
    };

    ping();
    const timer = window.setInterval(ping, INTERVAL_MS);
    document.addEventListener("visibilitychange", ping);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", ping);
    };
  }, []);

  return null;
}
