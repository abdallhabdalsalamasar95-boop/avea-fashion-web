"use client";

import Link from "next/link";
import { ChevronDown, Clock3, MapPin, PackageCheck, Trash2, UserRound } from "lucide-react";
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
  customer?: {
    name?: string;
    phone?: string;
    city?: string;
    address?: string;
  };
  footerExtra?: ReactNode;
  onCancel?: () => void;
  canceling?: boolean;
  compact?: boolean;
}

export function OrderCard({ orderId, status, createdAt, total, itemCount, items = [], delivery, customer, footerExtra, onCancel, canceling = false, compact = false }: OrderCardProps) {
  const [expanded, setExpanded] = useState(!compact);
  const detailsId = useId();
  const firstItem = items[0];
  const formattedDate = new Intl.DateTimeFormat("ar-LY", { dateStyle: compact ? "short" : "medium", timeStyle: "short" }).format(createdAt);

  return <article className={`order-detail-card tracked-order-card status-${status}${compact ? " ambassador-compact-order" : ""}${expanded ? " expanded" : ""}`}>
    {compact ? <button className="ambassador-order-summary" type="button" aria-label={`${expanded ? "إخفاء" : "عرض"} تفاصيل الطلب ${orderId}`} aria-expanded={expanded} aria-controls={detailsId} onClick={() => setExpanded((current) => !current)}>
      <span className="ambassador-order-summary-copy"><strong>{customer?.name || "طلبك"}</strong><small><b dir="ltr">#{orderId}</b> • {formattedDate}</small><em>{firstItem?.name || `${itemCount} ${itemCount === 1 ? "قطعة" : "قطع"}`}</em></span>
      <span className="ambassador-order-summary-meta"><em className={`order-status ${status}`}>{orderStatusLabels[status]}</em><b>{total.toFixed(2)} د.ل</b>{delivery?.referenceCode && <small className="order-summary-shipment"><PackageCheck /> {delivery.referenceCode}</small>}{footerExtra}</span>
      <ChevronDown aria-hidden="true" className="ambassador-order-expand-icon" />
    </button> : <header className="saved-order-main order-detail-card-head">
      <div className="order-icon"><Clock3 /></div>
      <div className="order-card-identity"><small>رقم الطلب</small><strong dir="ltr">{orderId}</strong><span>{formattedDate} • {itemCount} قطعة</span></div>
      <div className="saved-order-total"><b>{total.toFixed(2)} د.ل</b><em className={`order-status ${status}`}>{orderStatusLabels[status]}</em></div>
    </header>}
    {expanded && <div className={compact ? "ambassador-order-expanded" : ""} id={detailsId}>
      {customer && <div className="order-customer-details">
        <div><UserRound /><span><small>بيانات العميلة</small><strong>{customer.name || "غير محدد"}</strong>{customer.phone && <b dir="ltr">{customer.phone}</b>}</span></div>
        <div><MapPin /><span><small>عنوان التوصيل</small><strong>{[customer.city, customer.address].filter(Boolean).join(" - ") || "غير محدد"}</strong></span></div>
      </div>}
      <OrderTrackingTimeline status={status} delivery={delivery} />
      <div className="order-product-lines">
        {items.length ? items.map((item, index) => <div className="order-product-line" key={`${item.productId ?? "item"}-${index}`}>
          <Link aria-label={item.name || "عرض المنتج"} href={item.productId ? `/product/?id=${encodeURIComponent(item.productId)}` : "#"}><ProductImage src={item.imageUrl} alt={item.name ?? "الموديل"} /></Link>
          <div className="order-product-copy"><strong>{item.name || "موديل بدون اسم"}</strong>{item.productCode && <small>كود: {item.productCode}</small>}<span>{[item.size && `المقاس ${item.size}`, item.length && `الطول ${item.length}`, item.color && `اللون ${item.color}`].filter(Boolean).join(" • ") || "بدون خيارات"}</span></div>
          <div className="order-product-meta"><span><small>الكمية</small><strong>{item.quantity ?? 0}</strong></span><span><small>السعر</small><strong>{Number(item.price ?? 0).toFixed(2)} د.ل</strong></span></div>
        </div>) : <p className="order-products-unavailable">تفاصيل المنتجات غير متاحة لهذا الطلب القديم.</p>}
      </div>
      <footer className="order-card-footer"><span>{itemCount} قطعة</span><span>قيمة الطلب <strong>{total.toFixed(2)} د.ل</strong></span>{!compact && footerExtra}{onCancel && <button className="order-cancel-button" type="button" disabled={canceling} onClick={onCancel}><Trash2 /> {canceling ? "جاري الإلغاء..." : "إلغاء الطلب"}</button>}</footer>
    </div>}
  </article>;
}