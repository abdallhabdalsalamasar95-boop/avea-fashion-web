"use client";

import Link from "next/link";
import { ChevronDown, Clock3, MapPin, PackageCheck, PhoneCall, RotateCcw, Trash2, UserRound } from "lucide-react";
import { ReactNode, useId, useState } from "react";
import { OrderTrackingTimeline, orderStatusLabels } from "@/components/order-tracking-timeline";
import { ProductImage } from "@/components/product-image";
import { ExternalDeliveryTracking, OrderProductLine, OrderStatus } from "@/lib/types";

interface OrderCardProps {
  orderId: string;
  status: OrderStatus;
  createdAt: number;
  total: number;
  itemCount: number;
  items?: OrderProductLine[];
  delivery?: ExternalDeliveryTracking;
  ambassadorPhone?: string;
  statusReason?: string;
  statusReasonImageUrl?: string;
  customer?: {
    name?: string;
    phone?: string;
    city?: string;
    address?: string;
  };
  footerExtra?: ReactNode;
  onCancel?: () => void;
  onReorder?: () => void;
  reordering?: boolean;
  canceling?: boolean;
  compact?: boolean;
}

export function OrderCard({ orderId, status, createdAt, total, itemCount, items = [], delivery, ambassadorPhone, statusReason, statusReasonImageUrl, customer, footerExtra, onCancel, onReorder, reordering = false, canceling = false, compact = false }: OrderCardProps) {
  const [expanded, setExpanded] = useState(!compact);
  const detailsId = useId();
  const firstItem = items[0];
  const detailItems = compact ? items.slice(1) : items;
  const shortOrderId = orderId.replace(/^o_/, "").split("_")[0].slice(-5) || orderId.slice(-5);
  const formattedDate = new Intl.DateTimeFormat("ar-LY", { dateStyle: compact ? "short" : "medium", timeStyle: "short" }).format(createdAt);

  return <article className={`order-detail-card tracked-order-card status-${status}${compact ? " ambassador-compact-order" : ""}${expanded ? " expanded" : ""}`}>
    {compact ? <button className="ambassador-order-summary" type="button" aria-label={`${expanded ? "إخفاء" : "عرض"} تفاصيل الطلب ${orderId}`} aria-expanded={expanded} aria-controls={detailsId} onClick={() => setExpanded((current) => !current)}>
      <span className="ambassador-order-thumb"><ProductImage src={firstItem?.imageUrl} alt={firstItem?.name ?? "الموديل"} /></span>
      <span className="ambassador-order-summary-copy"><strong>{customer?.name || "طلبك"}</strong><small title={orderId}><b dir="ltr">#{shortOrderId}</b> • {formattedDate}</small><em>{firstItem?.name || `${itemCount} ${itemCount === 1 ? "قطعة" : "قطع"}`}</em></span>
      <span className="ambassador-order-summary-meta"><em className={`order-status ${status}`}>{orderStatusLabels[status]}</em><b>{total.toFixed(2)} د.ل</b><span className="order-summary-representative">{delivery?.courierPhone ? <><b dir="ltr">{delivery.courierPhone}</b><a dir="ltr" href={`tel:${delivery.courierPhone}`} onClick={(event) => event.stopPropagation()}><PhoneCall /> اتصال</a></> : <small>مندوب التوصيل غير معيّن</small>}</span>{(status === "postponed" || status === "canceled") && (statusReason || delivery?.lastError || statusReasonImageUrl) && <span className="order-summary-reason">{(statusReason || delivery?.lastError) && <small>{statusReason || delivery?.lastError}</small>}{statusReasonImageUrl && <a href={statusReasonImageUrl} target="_blank" rel="noreferrer" onClick={(event) => event.stopPropagation()}><img src={statusReasonImageUrl} alt="صورة السبب" /></a>}</span>}{delivery?.referenceCode && <small className="order-summary-shipment"><PackageCheck /> {delivery.referenceCode}</small>}{footerExtra}</span>
      <ChevronDown aria-hidden="true" className="ambassador-order-expand-icon" />
    </button> : <header className="saved-order-main order-detail-card-head">
      <div className="order-icon"><Clock3 /></div>
      <div className="order-card-identity"><small>رقم الطلب</small><strong dir="ltr" title={orderId}>#{shortOrderId}</strong><span>{formattedDate} • {itemCount} قطعة</span></div>
      <div className="saved-order-total"><b>{total.toFixed(2)} د.ل</b><em className={`order-status ${status}`}>{orderStatusLabels[status]}</em></div>
    </header>}
    {expanded && <div className={compact ? "ambassador-order-expanded" : ""} id={detailsId}>
      {customer && <div className="order-customer-details">
        <div><UserRound /><span><small>بيانات العميلة</small><strong>{customer.name || "غير محدد"}</strong>{customer.phone && <b dir="ltr">{customer.phone}</b>}</span></div>
        <div><MapPin /><span><small>عنوان التوصيل</small><strong>{[customer.city, customer.address].filter(Boolean).join(" - ") || "غير محدد"}</strong></span></div>
      </div>}
      <div className="order-representative"><UserRound /><span><small>رقم مندوب التوصيل</small>{delivery?.courierPhone ? <b dir="ltr">{delivery.courierPhone}</b> : <b>غير متوفر بعد</b>}</span>{delivery?.courierPhone && <a className="order-representative-call" dir="ltr" href={`tel:${delivery.courierPhone}`}><PhoneCall /> اتصال</a>}</div>
      {(status === "postponed" || status === "canceled") ? ((statusReason || delivery?.lastError || statusReasonImageUrl) && <div className={`order-status-reason ${status}`}>{(statusReason || delivery?.lastError) && <p>{statusReason || delivery?.lastError}</p>}{statusReasonImageUrl && <a href={statusReasonImageUrl} target="_blank" rel="noreferrer"><img src={statusReasonImageUrl} alt="صورة السبب" /></a>}</div>) : <OrderTrackingTimeline status={status} delivery={delivery} orderId={orderId} />}
      {detailItems.length > 0 && <div className="order-product-lines">
        {detailItems.map((item, index) => <div className="order-product-line" key={`${item.productId ?? "item"}-${index}`}>
          <Link aria-label={item.name || "عرض المنتج"} href={item.productId ? `/product/?id=${encodeURIComponent(item.productId)}` : "#"}><ProductImage src={item.imageUrl} alt={item.name ?? "الموديل"} /></Link>
          <div className="order-product-copy"><strong>{item.name || "موديل بدون اسم"}</strong>{item.productCode && <small>كود: {item.productCode}</small>}<span>{[item.size && `المقاس ${item.size}`, item.length && `الطول ${item.length}`, item.color && `اللون ${item.color}`].filter(Boolean).join(" • ") || "بدون خيارات"}</span></div>
          <div className="order-product-meta"><span><small>الكمية</small><strong>{item.quantity ?? 0}</strong></span><span><small>السعر</small><strong>{Number(item.price ?? 0).toFixed(2)} د.ل</strong></span></div>
        </div>)}</div>}
      {!detailItems.length && !items.length && <p className="order-products-unavailable">تفاصيل المنتجات غير متاحة لهذا الطلب القديم.</p>}
      <footer className="order-card-footer"><span>{itemCount} قطعة</span><span>قيمة الطلب <strong>{total.toFixed(2)} د.ل</strong></span>{!compact && footerExtra}{onReorder && status === "canceled" && <button className="order-reorder-button" type="button" disabled={reordering} onClick={onReorder}><RotateCcw /> {reordering ? "جاري الإضافة..." : "إعادة الطلب"}</button>}{onCancel && <button className="order-cancel-button" type="button" disabled={canceling} onClick={onCancel}><Trash2 /> {canceling ? "جاري الإلغاء..." : "إلغاء الطلب"}</button>}</footer>
    </div>}
  </article>;
}