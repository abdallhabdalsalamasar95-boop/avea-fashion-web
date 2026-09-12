"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { PackageCheck, PhoneCall, ShieldCheck, UserPlus } from "lucide-react";
import { fetchOrderTracking } from "@/lib/api";
import { OrderTrackingTimeline, orderStatusLabels } from "@/components/order-tracking-timeline";
import { ProductImage } from "@/components/product-image";
import { OrderProductLine, OrderStatus, TrackedOrder } from "@/lib/types";

const status = (value: string): OrderStatus =>
  ["pending", "processing", "shipped", "postponed", "delivered", "canceled", "returning", "returned"].includes(value)
    ? value as OrderStatus
    : "pending";

const customerReason = (value: string, currentStatus: OrderStatus): string => {
  const reason = String(value || "").trim();
  if (!reason || /HTTP\s*\d+|api|provider|sync|token|request|invalid|bad request/i.test(reason)) {
    return currentStatus === "postponed" ? "سيتم تحديث موعد التوصيل عند توفره." : currentStatus === "returning" ? "الطلب في طريقه للعودة إلى المخزن." : currentStatus === "canceled" ? "تم إلغاء الطلب. تواصلي مع الدعم إذا احتجتِ المساعدة." : "";
  }
  return reason;
};

function TrackingView() {
  const params = useSearchParams();
  const orderId = params.get("order") || "";
  const token = params.get("token") || "";
  const [order, setOrder] = useState<TrackedOrder | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!orderId || !token) {
      setError("رابط التتبع غير مكتمل.");
      return;
    }
    let active = true;
    fetchOrderTracking(orderId, token)
      .then((value) => { if (active) setOrder(value); })
      .catch(() => { if (active) setError("تعذر فتح بيانات الطلب. تأكدي أن الرابط ما زال صالحًا."); });
    return () => { active = false; };
  }, [orderId, token]);

  if (error) return <main className="container inner-page"><div className="account-empty"><PackageCheck /><h1>تعذر فتح التتبع</h1><p>{error}</p><Link className="secondary-button" href="/">العودة للمتجر</Link></div></main>;
  if (!order) return <main className="container inner-page"><div className="page-loading">جاري تحميل حالة الطلب...</div></main>;

  const currentStatus = status(order.status);
  const items = order.items || [];
  return <main className="container inner-page tracking-share-page">
    <header className="tracking-share-hero"><ShieldCheck /><div><small>رابط متابعة آمن</small><h1>تتبع الطلب #{order.orderId.replace(/^o_/, "").slice(-8)}</h1><p>تتحدث الحالة تلقائيًا من لوحة المتجر ودرب السبيل.</p></div></header>
    <section className="tracking-share-card">
      <OrderTrackingTimeline status={currentStatus} delivery={order.externalDelivery} orderId={order.orderId} />
      {order.externalDelivery?.courierPhone ? <div className="tracking-share-courier"><span>رقم مندوب التوصيل</span><a dir="ltr" href={`tel:${order.externalDelivery.courierPhone}`}><PhoneCall /> اتصال بالمندوب</a></div> : <p className="tracking-share-note">سيظهر رقم مندوب التوصيل عند تعيينه.</p>}
      {customerReason(order.statusReason || order.externalDelivery?.lastError || "", currentStatus) && <div className={`tracking-share-reason ${currentStatus}`}><strong>{currentStatus === "postponed" ? "سبب التأجيل" : currentStatus === "returning" || currentStatus === "returned" ? "سبب الإرجاع" : "ملاحظة الطلب"}</strong><p>{customerReason(order.statusReason || order.externalDelivery?.lastError || "", currentStatus)}</p>{order.statusReasonImageUrl && <a href={order.statusReasonImageUrl} target="_blank" rel="noreferrer"><img src={order.statusReasonImageUrl} alt="صورة سبب حالة الطلب" /></a>}</div>}
      {items.length > 0 && <div className="tracking-share-items"><h2>محتويات الطلب</h2>{items.map((item, index) => <TrackingLine key={`${item.productId || "line"}-${index}`} item={item} />)}</div>}
      <footer className="tracking-share-total"><span>{order.itemCount || items.reduce((sum, item) => sum + Number(item.quantity || 0), 0)} قطعة</span><strong>{Number(order.total || 0).toFixed(2)} د.ل</strong></footer>
    </section>
    <section className="tracking-create-account"><UserPlus /><div><strong>احفظي طلبك وتابعي طلباتك بسهولة</strong><p>إنشاء حساب اختياري لحفظ طلباتك على جميع أجهزتك.</p></div><Link className="secondary-button" href="/account/">إنشاء حساب</Link></section>
    <p className="tracking-share-note">هذا الرابط يعرض حالة الطلب ورقم المندوب فقط، ولا يعرض بيانات الدفع أو عنوان التوصيل الكامل.</p>
  </main>;
}

function TrackingLine({ item }: { item: OrderProductLine }) {
  const options = [item.size && `المقاس ${item.size}`, item.length && `الطول ${item.length}`, item.color && `اللون ${item.color}`].filter(Boolean).join(" • ");
  return <article className="tracking-share-line"><ProductImage src={item.imageUrl} alt={item.name || "المنتج"} /><div><strong>{item.name || "منتج"}</strong><span>{options || "بدون خيارات"} · الكمية {item.quantity || 0}</span></div></article>;
}

export default function TrackPage() {
  return <Suspense fallback={<main className="container inner-page"><div className="page-loading">جاري التحميل...</div></main>}><TrackingView /></Suspense>;
}
