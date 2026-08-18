"use client";

import { MessageCircle } from "lucide-react";

function whatsappDigits(value: string): string {
  let digits = value.replace(/\D/g, "");
  if (digits.startsWith("00")) digits = digits.slice(2);
  if (digits.startsWith("0")) digits = `218${digits.slice(1)}`;
  else if (digits.length === 9 && digits.startsWith("9")) digits = `218${digits}`;
  return /^\d{7,15}$/.test(digits) ? digits : "";
}

export function AmbassadorSupportButton({ number, enabled }: { number?: string; enabled?: boolean }) {
  const digits = whatsappDigits(number ?? "");
  if (!enabled || !digits) return null;
  const message = encodeURIComponent("مرحبًا، أحتاج مساعدة بخصوص برنامج مندوبات Carmen Karla");
  return <a className="ambassador-whatsapp-float" href={`https://wa.me/${digits}?text=${message}`} target="_blank" rel="noreferrer" aria-label="التواصل مع دعم المندوبات عبر واتساب"><MessageCircle /><span>دعم المندوبات</span></a>;
}