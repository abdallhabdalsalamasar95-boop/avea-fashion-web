"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import {
  AlertCircle,
  Calendar,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock,
  Copy,
  ExternalLink,
  ImageIcon,
  MapPin,
  MessageCircle,
  PackageCheck,
  PhoneCall,
  Share2,
  ShieldCheck,
  Sparkles,
  Truck,
  User,
  UserPlus,
  X,
} from "lucide-react";
import { fetchOrderTracking } from "@/lib/api";
import { OrderTrackingTimeline, orderStatusLabels } from "@/components/order-tracking-timeline";
import { ProductImage } from "@/components/product-image";
import { SuggestedProducts } from "@/components/suggested-products";
import { AuthPanel } from "@/components/auth-panel";
import { useAuth } from "@/components/auth-provider";
import { useToast } from "@/components/toast-provider";
import { writeCustomerOrders, readCustomerOrders } from "@/lib/customer-storage";
import { OrderProductLine, OrderStatus, TrackedOrder, SavedCustomerOrder } from "@/lib/types";

const money = (value: number) => new Intl.NumberFormat("ar-LY", { maximumFractionDigits: 2 }).format(value);

const status = (value: string): OrderStatus =>
  ["pending", "processing", "shipped", "postponed", "delivered", "canceled", "returning", "returned"].includes(value)
    ? (value as OrderStatus)
    : "pending";

const customerReason = (value: string, currentStatus: OrderStatus): string => {
  const reason = String(value || "").trim();
  if (!reason || /HTTP\s*\d+|api|provider|sync|token|request|invalid|bad request/i.test(reason)) {
    return currentStatus === "postponed"
      ? "سيتم تحديث موعد التوصيل عند توفره."
      : currentStatus === "returning"
      ? "الطلب في طريقه للعودة إلى المخزن."
      : currentStatus === "canceled"
      ? "تم إلغاء الطلب. تواصلي مع الدعم إذا احتجتِ المساعدة."
      : "";
  }
  return reason;
};

function TrackingView() {
  const params = useSearchParams();
  const orderId = params.get("order") || "";
  const token = params.get("token") || "";
  const { user } = useAuth();
  const { showToast } = useToast();
  const [order, setOrder] = useState<TrackedOrder | null>(null);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);
  const [showAuth, setShowAuth] = useState(false);
  const [activeImageIndex, setActiveImageIndex] = useState<number | null>(null);

  useEffect(() => {
    if (!orderId || !token) {
      setError("رابط التتبع غير مكتمل.");
      return;
    }
    let active = true;
    fetchOrderTracking(orderId, token)
      .then((value) => {
        if (active) {
          setOrder(value);
          // Auto-save to customer local storage so order is accessible in account
          const savedList: SavedCustomerOrder[] = readCustomerOrders(user?.uid);
          const existingIdx = savedList.findIndex((o) => o.orderId === value.orderId);
          const savedOrder: SavedCustomerOrder = {
            orderId: value.orderId,
            createdAt: value.createdAtMs,
            total: value.total || 0,
            itemCount: value.itemCount || (value.items?.length || 0),
            status: value.status,
            trackingToken: token,
            externalDelivery: value.externalDelivery,
            ownerUid: user?.uid,
            items: value.items,
            ambassadorPhone: value.ambassadorPhone,
            statusReason: value.statusReason,
            statusReasonImageUrl: value.statusReasonImageUrl,
            statusReasonImageUrls: value.statusReasonImageUrls,
            shippingCost: value.shippingCost,
            customerCity: value.customerCity,
            customerArea: value.customerArea,
          };
          if (existingIdx >= 0) {
            savedList[existingIdx] = savedOrder;
          } else {
            savedList.unshift(savedOrder);
          }
          writeCustomerOrders(savedList, user?.uid);
        }
      })
      .catch(() => {
        if (active) setError("تعذر فتح بيانات الطلب. تأكدي أن الرابط ما زال صالحًا.");
      });
    return () => {
      active = false;
    };
  }, [orderId, token, user]);

  const handleShare = async () => {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({
          title: `تتبع طلب Carmen Karla #${order?.orderId.replace(/^o_/, "").slice(-8)}`,
          text: `تابعي حالة طلبك من Carmen Karla بكل سهولة:`,
          url,
        });
        return;
      } catch {
        // Fallback to clipboard
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      showToast("تم نسخ رابط التتبع بنجاح");
      setTimeout(() => setCopied(false), 2200);
    } catch {
      setCopied(true);
      showToast("تم نسخ رابط التتبع");
      setTimeout(() => setCopied(false), 2200);
    }
  };

  if (error)
    return (
      <main className="container inner-page">
        <div className="account-empty">
          <PackageCheck />
          <h1>تعذر فتح التتبع</h1>
          <p>{error}</p>
          <Link className="secondary-button" href="/">
            العودة للمتجر
          </Link>
        </div>
      </main>
    );

  if (!order)
    return (
      <main className="container inner-page">
        <div className="page-loading">جاري تحميل حالة الطلب...</div>
      </main>
    );

  const currentStatus = status(order.status);
  const items = order.items || [];
  const reasonText = customerReason(order.statusReason || order.externalDelivery?.lastError || "", currentStatus);
  const reasonImages = order.statusReasonImageUrls && order.statusReasonImageUrls.length > 0
    ? order.statusReasonImageUrls
    : order.statusReasonImageUrl
    ? [order.statusReasonImageUrl]
    : [];

  const courierPhone = order.externalDelivery?.courierPhone;
  const courierName = order.externalDelivery?.courierName || "مندوب التوصيل";
  const whatsappUrl = courierPhone
    ? `https://wa.me/218${courierPhone.replace(/\D/g, "").replace(/^0/, "")}?text=${encodeURIComponent(
        `مرحبًا، أنا بخصوص طلبي رقم #${order.orderId.replace(/^o_/, "").slice(-8)} من Carmen Karla`
      )}`
    : "";

  return (
    <main className="container inner-page tracking-share-page">
      {/* Hero Header */}
      <header className="tracking-share-hero">
        <ShieldCheck />
        <div className="tracking-hero-content">
          <small>متابعة سهلة</small>
          <h1>تتبع الطلب #{order.orderId.replace(/^o_/, "").slice(-8)}</h1>
          <p>احتفظي بهذه الصفحة لمعرفة آخر حالة لطلبك.</p>
        </div>
      </header>

      {/* Main Tracking Card */}
      <section className="tracking-share-card">
        {/* Simplified Visual Timeline */}
        <OrderTrackingTimeline status={currentStatus} delivery={order.externalDelivery} orderId={order.orderId} />

        {/* Courier Section */}
        {courierPhone ? (
          <div className="tracking-courier-card">
            <div className="courier-card-header">
              <div className="courier-avatar">
                <Truck />
              </div>
              <div className="courier-meta">
                <span className="courier-badge">مندوب التوصيل</span>
                <strong className="courier-name">{courierName}</strong>
                <span className="courier-phone" dir="ltr">{courierPhone}</span>
              </div>
            </div>
            <div className="courier-actions">
              <a href={`tel:${courierPhone}`} className="courier-btn call-btn">
                <PhoneCall /> اتصال بالمندوب
              </a>
              {whatsappUrl && (
                <a href={whatsappUrl} target="_blank" rel="noreferrer" className="courier-btn whatsapp-btn">
                  <MessageCircle /> تواصل عبر واتساب
                </a>
              )}
            </div>
          </div>
        ) : (
          <div className="tracking-courier-card placeholder">
            <Truck />
            <p className="tracking-share-note">سيتم إظهار اسم ورقم مندوب التوصيل فور تعيينه للطلب.</p>
          </div>
        )}

        {/* Reason Card with Multiple Images Gallery (if canceled/postponed/returned) */}
        {reasonText && (
          <div className={`tracking-share-reason ${currentStatus}`}>
            <div className="reason-header">
              <AlertCircle />
              <strong>
                {currentStatus === "postponed"
                  ? "سبب التأجيل"
                  : currentStatus === "returning" || currentStatus === "returned"
                  ? "سبب الإرجاع"
                  : currentStatus === "canceled"
                  ? "سبب الإلغاء"
                  : "ملاحظة على الطلب"}
              </strong>
            </div>
            <p className="reason-text">{reasonText}</p>

            {(currentStatus === "returning" || currentStatus === "returned") && (
              <div className="returning-items-warning">
                <strong>القطع المُرجعة:</strong>
                <p>هذه القطع قيد الإرجاع إلى المخزن. سيتم إعادة النظر في طلبك بعد استلام المنتجات.</p>
              </div>
            )}

            {/* Multiple Reason Images Gallery */}
            {reasonImages.length > 0 && (
              <div className="reason-gallery">
                <span className="reason-gallery-title"><ImageIcon /> صور توضيحية مرفقة ({reasonImages.length})</span>
                <div className="reason-images-grid">
                  {reasonImages.map((src, idx) => (
                    <button
                      type="button"
                      key={idx}
                      className="reason-thumb-btn"
                      onClick={() => setActiveImageIndex(idx)}
                      aria-label={`عرض الصورة المرفقة ${idx + 1}`}
                    >
                      <img src={src} alt={`صورة توضيحية لسبب الحالة ${idx + 1}`} loading="lazy" />
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Order Products Lines */}
        {items.length > 0 && (
          <div className="tracking-share-items">
            <h2>محتويات الطلب ({order.itemCount || items.reduce((sum, item) => sum + Number(item.quantity || 0), 0)} قطعة)</h2>
            <div className="tracking-lines-list">
              {items.map((item, index) => (
                <TrackingLine key={`${item.productId || "line"}-${index}`} item={item} />
              ))}
            </div>
          </div>
        )}

        {/* Financial & Location Summary */}
        <div className="tracking-order-summary">
          {order.customerCity && (
            <div className="summary-row location-row">
              <span className="summary-label"><MapPin /> مدينة التوصيل</span>
              <strong>{order.customerCity}{order.customerArea ? ` - ${order.customerArea}` : ""}</strong>
            </div>
          )}
          {order.shippingCost !== undefined && order.shippingCost > 0 && (
            <div className="summary-row">
              <span className="summary-label">رسوم التوصيل</span>
              <span>{money(order.shippingCost)} د.ل</span>
            </div>
          )}
          <footer className="tracking-share-total">
            <span>الإجمالي النهائي</span>
            <strong>{money(order.total || 0)} د.ل</strong>
          </footer>
        </div>
      </section>

      {/* Account Integration & Save CTA */}
      {!user ? (
        <section className="tracking-create-account">
          <UserPlus />
          <div className="account-cta-content">
            <strong>احفظي طلبك وتابعي طلباتك بسهولة</strong>
            <p>سجّلي الدخول أو أنشئي حسابًا اختياريًا لحفظ هذا الطلب ومتابعته من أي جهاز.</p>
          </div>
          <button className="secondary-button" onClick={() => setShowAuth(!showAuth)}>
            {showAuth ? "إخفاء تسجيل الدخول" : "تسجيل الدخول / إنشاء حساب"}
          </button>
        </section>
      ) : (
        <section className="tracking-saved-banner">
          <Check />
          <div>
            <strong>تم حفظ هذا الطلب في حسابك</strong>
            <p>يمكنك دائمًا مراجعته من صفحة <Link href="/account/">حسابي وطلباتي</Link>.</p>
          </div>
        </section>
      )}

      {/* Inline Auth Modal/Panel if expanded */}
      {showAuth && !user && (
        <div className="tracking-auth-wrapper">
          <AuthPanel
            title="حفظ الطلب في حسابك"
            subtitle="سجّلي الدخول لربط هذا الطلب بحسابك تلقائيًا."
            onSuccess={() => setShowAuth(false)}
          />
        </div>
      )}

      <p className="tracking-privacy-note">احتفظي بهذا الرابط لمتابعة طلبك بسهولة في أي وقت.</p>

      {/* Suggested Models & Other Collections at the bottom */}
      <SuggestedProducts
        currentProductId={items[0]?.productId}
        title="موديلات أخرى قد تعجبك"
        subtitle="اكتشفي تشكيلة Carmen Karla المميزة"
        limit={4}
        className="tracking-suggested-section"
      />

      {/* Fullscreen Lightbox Modal for Reason Images */}
      {activeImageIndex !== null && reasonImages[activeImageIndex] && (
        <div className="lightbox-overlay" onClick={() => setActiveImageIndex(null)} role="dialog" aria-modal="true">
          <button className="lightbox-close" onClick={() => setActiveImageIndex(null)} aria-label="إغلاق">
            <X />
          </button>
          {reasonImages.length > 1 && (
            <button
              className="lightbox-nav prev"
              onClick={(e) => {
                e.stopPropagation();
                setActiveImageIndex((activeImageIndex - 1 + reasonImages.length) % reasonImages.length);
              }}
              aria-label="الصورة السابقة"
            >
              <ChevronRight />
            </button>
          )}
          <img
            src={reasonImages[activeImageIndex]}
            alt="صورة مكبرة لسبب حالة الطلب"
            className="lightbox-img"
            onClick={(e) => e.stopPropagation()}
          />
          {reasonImages.length > 1 && (
            <button
              className="lightbox-nav next"
              onClick={(e) => {
                e.stopPropagation();
                setActiveImageIndex((activeImageIndex + 1) % reasonImages.length);
              }}
              aria-label="الصورة التالية"
            >
              <ChevronLeft />
            </button>
          )}
        </div>
      )}
    </main>
  );
}

function TrackingLine({ item }: { item: OrderProductLine }) {
  const options = [
    item.size && `المقاس ${item.size}`,
    item.length && `الطول ${item.length}`,
    item.color && `اللون ${item.color}`,
  ]
    .filter(Boolean)
    .join(" • ");

  return (
    <article className="tracking-share-line">
      <div className="tracking-line-media">
        <ProductImage src={item.imageUrl} alt={item.name || "المنتج"} />
      </div>
      <div className="tracking-line-info">
        <strong>{item.name || "منتج"}</strong>
        <span className="tracking-line-options">{options || "بدون خيارات"}</span>
        <div className="tracking-line-meta">
          <span>الكمية: {item.quantity || 1}</span>
          {item.price ? <strong>{money(item.price * (item.quantity || 1))} د.ل</strong> : null}
        </div>
      </div>
    </article>
  );
}

export default function TrackPage() {
  return (
    <Suspense
      fallback={
        <main className="container inner-page">
          <div className="page-loading">جاري التحميل...</div>
        </main>
      }
    >
      <TrackingView />
    </Suspense>
  );
}
