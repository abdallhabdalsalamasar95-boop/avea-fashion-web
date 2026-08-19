"use client";

import { Ban, Check, Clock3, PackageCheck, PauseCircle, RotateCcw, Truck } from "lucide-react";
import { ExternalDeliveryTracking, OrderStatus } from "@/lib/types";

const statusLabels: Record<OrderStatus, string> = {
  pending: "قيد الانتظار",
  processing: "تم القبول",
  shipped: "قيد التوصيل",
  postponed: "مؤجلة",
  delivered: "تم التوصيل",
  canceled: "ملغي",
  returning: "الشحنة راجعة",
  returned: "تم إرجاع الشحنة",
};

const forwardSteps: Array<{ status: OrderStatus; label: string }> = [
  { status: "pending", label: "قيد الانتظار" },
  { status: "processing", label: "تم القبول" },
  { status: "shipped", label: "قيد التوصيل" },
  { status: "delivered", label: "تم التوصيل" },
];

const rank: Partial<Record<OrderStatus, number>> = { pending: 0, processing: 1, shipped: 2, delivered: 3 };

export function OrderTrackingTimeline({ status, delivery, compact = false, orderId = "" }: { status: OrderStatus; delivery?: ExternalDeliveryTracking; compact?: boolean; orderId?: string }) {
  const isReturn = status === "returning" || status === "returned";
  const isInterrupted = status === "postponed" || status === "canceled";
  const steps = isReturn
    ? [...forwardSteps.slice(0, 3), { status: "returning" as const, label: "راجعة" }, { status: "returned" as const, label: "تم الإرجاع" }]
    : forwardSteps;
  const currentRank = isReturn ? (status === "returned" ? 4 : 3) : status === "postponed" ? 0 : (rank[status] ?? -1);
  const events = [...(delivery?.timeline ?? [])].sort((a, b) => Date.parse(a.timestamp ?? "") - Date.parse(b.timestamp ?? ""));
  const tracking = delivery?.referenceCode || delivery?.trackingNumber || delivery?.shipmentId;

  return <section className={`tracking-panel${compact ? " compact" : ""}`}>
    <header className="tracking-head">
      <span><Truck /></span>
      <div><small>تتبّع درب السبيل</small><strong>{statusLabels[status] ?? status}</strong></div>
      {tracking && <b dir="ltr">{tracking}</b>}
    </header>
    {status !== "canceled" && <div className={`tracking-steps${isReturn ? " return-path" : ""}${isInterrupted ? " interrupted" : ""}`}>
      {steps.map((step, index) => {
        const active = index <= currentRank;
        const current = step.status === status;
        return <div className={`${active ? "active" : ""}${current ? " current" : ""}`} key={step.status}>
          <i>{active ? <Check /> : step.status === "returned" || step.status === "returning" ? <RotateCcw /> : index === 3 ? <PackageCheck /> : <Clock3 />}</i>
          <span>{step.label}</span>
        </div>;
      })}
    </div>}
    {status === "postponed" && <div className="tracking-outcome postponed"><PauseCircle /><span><strong>تم تأجيل التوصيل</strong><small>هذه الحالة واردة مباشرة من درب السبيل. سيظهر أي موعد أو تحديث جديد هنا تلقائيًا.</small></span></div>}
    {status === "canceled" && <div className="tracking-outcome canceled"><Ban /><span><strong>تم إلغاء الشحنة</strong><small>{delivery?.lastError || "ألغت شركة التوصيل الشحنة أو حُذفت من درب السبيل."}</small><a href={`https://wa.me/218921397674?text=${encodeURIComponent(`مرحبًا، أحتاج مساعدة بخصوص الطلب ${orderId}${delivery?.lastError ? ` — ${delivery.lastError}` : ""}`)}`} target="_blank" rel="noreferrer">تواصل مع الدعم عبر واتساب</a></span></div>}
    {status !== "canceled" && !compact && events.length > 0 && <div className="tracking-events">
      {events.map((event, index) => <article key={event.id || `${event.type}-${index}`}>
        <i />
        <div><strong>{event.descriptionAr || event.descriptionEn || "تحديث على الشحنة"}</strong>{event.timestamp && <time>{new Intl.DateTimeFormat("ar-LY", { dateStyle: "medium", timeStyle: "short" }).format(new Date(event.timestamp))}</time>}</div>
      </article>)}
    </div>}
    {delivery?.lastSyncAtMs && <small className="tracking-sync">آخر تحديث: {new Intl.DateTimeFormat("ar-LY", { dateStyle: "short", timeStyle: "short" }).format(delivery.lastSyncAtMs)}</small>}
  </section>;
}

export { statusLabels as orderStatusLabels };
