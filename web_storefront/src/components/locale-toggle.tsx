"use client";
import { useEffect, useState } from "react";
export function LocaleToggle() {
  const [locale, setLocale] = useState("ar");
  useEffect(() => setLocale(localStorage.getItem("avea.locale") || "ar"), []);
  const toggle = () => { const next = locale === "ar" ? "en" : "ar"; setLocale(next); localStorage.setItem("avea.locale", next); document.documentElement.lang = next; document.documentElement.dir = next === "ar" ? "rtl" : "ltr"; };
  return <button className="locale-toggle" onClick={toggle} aria-label="تغيير اللغة">{locale === "ar" ? "EN" : "ع"}</button>;
}
