"use client";

import Link from "next/link";
import { BadgeCheck, Check, CheckCircle2, CircleDollarSign, Clipboard, LockKeyhole, MapPin, PackageSearch, Share2, ShoppingBag } from "lucide-react";
import { FormEvent, Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAmbassador } from "@/components/ambassador-context";
import { DeliveryLocationFields } from "@/components/delivery-location-fields";
import { ProductImage } from "@/components/product-image";
import { useAuth } from "@/components/auth-provider";
import { useStore } from "@/components/store-provider";
import { useSiteAppearance } from "@/components/site-appearance-provider";
import { fetchAmbassadorShare, fetchAppContent, fetchShippingCost, submitOrder } from "@/lib/api";
import { clearAmbassadorShare, readAmbassadorShare, saveAmbassadorShare, seedAmbassadorShareToken } from "@/lib/ambassador-share";
import { lineCommission, totalCommission } from "@/lib/commission";
import { prependCustomerOrder, readCustomerProfile, writeCustomerProfile } from "@/lib/customer-storage";
import { AmbassadorShare, AppContent, CartItem, CheckoutCustomer } from "@/lib/types";

const fallbackShipping: Record<string, number> = { "طرابلس": 10, "بنغازي": 15, "مصراتة": 12, "سبها": 20, "الزاوية": 12, "سرت": 18, "درنة": 18, "طبرق": 20, "جالو اوجلة": 50, "جالو أوجلة": 50, "أخرى": 25 };
function CheckoutPageContent() {
  const { cart: storeCart, clearCart } = useStore();
  const searchParams = useSearchParams();
  const referralToken = (searchParams.get("ref") || "").trim();
  const isDirectCheckout = searchParams.get("direct") === "1";
  const [directCart] = useState<CartItem[]>(() => {
    if (typeof window === "undefined") return [];
    try { return JSON.parse(sessionStorage.getItem("carmen-karla.direct-checkout.v1") || "[]") as CartItem[]; } catch { return []; }
  });
  const checkoutCart = isDirectCheckout ? directCart : storeCart;
  const cart = checkoutCart;
  const checkoutTotal = checkoutCart.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const { user, loading: authLoading } = useAuth();
  const { ambassador, commission, loading: ambassadorLoading } = useAmbassador();
  const appearance = useSiteAppearance();
  const [customer, setCustomer] = useState<CheckoutCustomer>({ name: "", phone: "", address: "", city: "طرابلس", area: "" });
  const [couponCode, setCouponCode] = useState("");
  const [appliedCouponCode, setAppliedCouponCode] = useState("");
  const [couponFeedback, setCouponFeedback] = useState("");
  const [note, setNote] = useState("");
  const [content, setContent] = useState<AppContent>({});
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [orderId, setOrderId] = useState("");
  const [orderShared, setOrderShared] = useState(false);
  const [sharedOrder, setSharedOrder] = useState<AmbassadorShare | null>(null);
  const [shareLoaded, setShareLoaded] = useState(false);
  const [shippingCost, setShippingCost] = useState<number>(fallbackShipping["طرابلس"]);
  const checkoutAttemptId = useRef("");
  const profileInitialized = useRef(false);
  useEffect(() => {
    fetchAppContent().then(setContent).catch(() => {});
    if (referralToken) {
      seedAmbassadorShareToken(referralToken);
      const cached = readAmbassadorShare();
      if (cached?.token === referralToken) setSharedOrder(cached);
      fetchAmbassadorShare(referralToken)
        .then((share) => {
          saveAmbassadorShare(share);
          setSharedOrder(share);
        })
        .catch(() => {});
    } else {
      setSharedOrder(readAmbassadorShare());
    }
    setShareLoaded(true);
  }, [referralToken]);

  useEffect(() => {
    if (authLoading || ambassadorLoading || !shareLoaded || profileInitialized.current) return;
    profileInitialized.current = true;
    if (ambassador || sharedOrder) {
      setCustomer({ name: "", phone: "", address: "", city: "طرابلس", area: "" });
      return;
    }
    try {
      const savedProfile = readCustomerProfile(user?.uid);
      if (savedProfile) setCustomer({ ...customer, ...savedProfile });
    } catch {
      // Ignore malformed legacy browser storage.
    }
  }, [ambassador, ambassadorLoading, authLoading, customer, shareLoaded, sharedOrder, user?.uid]);

  useEffect(() => {
    if (!customer.city.trim()) {
      setShippingCost(0);
      return;
    }
    const controller = new AbortController();
    fetchShippingCost(customer.city, customer.area, controller.signal)
      .then((quote) => {
        if (!controller.signal.aborted && Number.isFinite(quote.amount)) setShippingCost(Math.max(0, quote.amount));
      })
      .catch(() => {
        if (!controller.signal.aborted) setShippingCost(fallbackShipping[customer.city] ?? fallbackShipping["أخرى"]);
      });
    return () => controller.abort();
  }, [customer.area, customer.city]);

  const pricing = useMemo(() => {
    const coupon = content.coupons?.find((item) => item.enabled !== false && Number(item.enabled ?? 1) !== 0 && item.code.toUpperCase() === appliedCouponCode && checkoutTotal >= (item.minSubtotal ?? 0));
    let discount = 0;
    let delivery = shippingCost;
    if (coupon?.type === "percent") discount = Math.min(checkoutTotal * coupon.value / 100, coupon.maxDiscount && coupon.maxDiscount > 0 ? coupon.maxDiscount : Number.POSITIVE_INFINITY);
    if (coupon?.type === "fixed") discount = Math.min(checkoutTotal, coupon.value);
    if (coupon?.type === "freeShipping" || coupon?.freeShipping === true || Number(coupon?.freeShipping ?? 0) === 1) delivery = 0;
    return { subtotal: checkoutTotal, discount, shippingCost: delivery, grandTotal: Math.max(0, checkoutTotal - discount + delivery), coupon };
  }, [appliedCouponCode, content.coupons, checkoutTotal, shippingCost]);
  const isCustomerSharedCheckout = Boolean(sharedOrder);
  const expectedCommission = totalCommission(checkoutCart, commission);
  const itemCount = checkoutCart.reduce((sum, item) => sum + item.quantity, 0);
  const confirmPanel = <div className="checkout-confirm-panel">{error && <p className="form-error">{error}</p>}<div><span><small>الإجمالي</small><strong>{pricing.grandTotal.toFixed(2)} د.ل</strong></span><button className="primary-button checkout-link" disabled={sending}>{sending ? "جاري الإرسال..." : "تأكيد الطلب"}</button></div><small className="secure-note"><LockKeyhole /> بياناتك تستخدم لإتمام الطلب فقط</small></div>;

  const applyCoupon = () => {
    const code = couponCode.trim().toUpperCase();
    const coupon = content.coupons?.find((item) => item.enabled !== false && Number(item.enabled ?? 1) !== 0 && item.code.toUpperCase() === code);
    if (!code || !coupon) {
      setAppliedCouponCode("");
      setCouponFeedback("الكود غير صالح أو متوقف");
      return;
    }
    if (checkoutTotal < (coupon.minSubtotal ?? 0)) {
      setAppliedCouponCode("");
      setCouponFeedback(`الحد الأدنى لاستخدام الكود ${(coupon.minSubtotal ?? 0).toFixed(2)} د.ل`);
      return;
    }
    setAppliedCouponCode(code);
    const hasFreeShipping = coupon.type === "freeShipping" || coupon.freeShipping === true || Number(coupon.freeShipping ?? 0) === 1;
    setCouponFeedback(hasFreeShipping ? "تم تطبيق الكوبون وتفعيل الشحن المجاني" : "تم تطبيق الكوبون بنجاح");
  };

  const removeCoupon = () => {
    setCouponCode("");
    setAppliedCouponCode("");
    setCouponFeedback("");
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault(); setError("");
    if (!checkoutCart.length) return setError("لم يتم اختيار منتج للشراء.");
    if (!customer.name.trim() || !customer.phone.trim() || !customer.area.trim() || !customer.address.trim()) return setError("يرجى تعبئة جميع بيانات التوصيل.");
    setSending(true);
    const id = checkoutAttemptId.current || `o_${Date.now()}_${crypto.randomUUID().slice(0, 8)}`;
    checkoutAttemptId.current = id;
    try {
      const idToken = user ? await user.getIdToken() : undefined;
      const ambassadorIdentity = ambassador && user ? {
        submitterUid: user.uid,
        submitterName: ambassador.ambassadorName,
        submitterEmail: user.email ?? ambassador.email,
        submitterPhone: ambassador.ambassadorPhone,
      } : {};
      const result = await submitOrder({ orderId: id, ambassadorShareToken: sharedOrder?.token || referralToken || undefined, payload: { customer: { ...customer, ...ambassadorIdentity, accountRole: ambassador ? "ambassador" : "customer", placedAsAmbassador: Boolean(ambassador) }, items: checkoutCart, pricing: { subtotal: pricing.subtotal, discount: pricing.discount, shippingCost: pricing.shippingCost, grandTotal: pricing.grandTotal }, paymentMethod: "الدفع عند الاستلام", couponCode: pricing.coupon?.code ?? "", note }, status: "pending", source: "web", uid: user?.uid ?? "" }, idToken);
      if (!ambassador && !sharedOrder) writeCustomerProfile(customer, user?.uid);
      if (!ambassador) prependCustomerOrder({ orderId: result.orderId, trackingToken: result.trackingToken, createdAt: Date.now(), total: pricing.grandTotal, itemCount, status: "pending", items: checkoutCart, orderChannel: "customer" }, user?.uid);
      clearAmbassadorShare(); setOrderId(result.orderId); if (isDirectCheckout) sessionStorage.removeItem("carmen-karla.direct-checkout.v1"); else clearCart();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "تعذر إرسال الطلب."); }
    finally { setSending(false); }
  };

  const shareOrder = async () => {
    const text = `تم تسجيل طلبي من Carmen Karla\nرقم الطلب: ${orderId}${sharedOrder ? `\nبمساعدة شريك Carmen Karla المعتمد ${sharedOrder.ambassadorName}` : ""}`;
    try {
      if (navigator.share) await navigator.share({ title: "طلب Carmen Karla", text, url: `${window.location.origin}${ambassador ? "/ambassador/" : "/account/#orders"}` });
      else await navigator.clipboard.writeText(text);
      setOrderShared(true);
      window.setTimeout(() => setOrderShared(false), 2200);
    } catch (reason) {
      if (!(reason instanceof DOMException && reason.name === "AbortError")) setOrderShared(false);
    }
  };

  if (orderId) return <div className="container success-page order-success"><div className="success-check"><CheckCircle2 /></div><span>شكرًا لاختياركِ Carmen Karla</span><h1>تم استلام طلبك بنجاح</h1>{sharedOrder && <div className="success-partner"><BadgeCheck /><span><small>بمساعدة شريك Carmen Karla المعتمد</small><strong>{sharedOrder.ambassadorName}</strong></span></div>}<div className="success-order-number"><small>رقم الطلب</small><strong dir="ltr">{orderId}</strong><Clipboard /></div><p>سيتواصل فريقنا معكِ لتأكيد التفاصيل، ويمكنكِ متابعة حالة الطلب في أي وقت.</p><div className="success-actions"><Link className="primary-button" href={ambassador ? "/ambassador/" : "/account/#orders"}><PackageSearch /> {ambassador ? "عرض طلبات عملائي" : "تتبع طلبي"}</Link><button className="secondary-button" onClick={shareOrder}>{orderShared ? <Check /> : <Share2 />}{orderShared ? "تمت المشاركة" : "مشاركة رقم الطلب"}</button></div><Link className="success-home-link" href="/">العودة للرئيسية</Link></div>;
  if (!checkoutCart.length) return <div className="container inner-page"><div className="empty-state"><h3>لا يمكن إتمام طلب فارغ</h3><Link className="primary-button" href="/#collection">العودة للمتجر</Link></div></div>;

  return <div className="container inner-page checkout-page"><header className="simple-page-head"><div><span>إتمام الطلب</span><h1>باقي خطوة واحدة</h1><p>أدخلي بيانات التوصيل ثم راجعي الطلب وأكّديه.</p></div><Link href="/cart/">العودة للسلة</Link></header><form className="checkout-layout" onSubmit={submit} autoComplete={ambassador || sharedOrder ? "off" : "on"}>
    <div className="checkout-form">{ambassador && !isCustomerSharedCheckout && <div className="ambassador-checkout-note"><BadgeCheck /><div><strong>طلب مسجّل باسم المندوب {ambassador.ambassadorName}</strong><span>العمولة المتوقعة {expectedCommission.toFixed(2)} د.ل وتُعتمد بعد نجاح التوصيل. بيانات العميلة لن تُحفظ على هذا الجهاز.</span></div></div>}{sharedOrder && <div className="ambassador-checkout-note customer-shared-note partner-checkout-note"><span className="partner-mark">CK</span><div><small>شريك Carmen Karla المعتمد</small><strong>{sharedOrder.ambassadorName}</strong><span>نسّق اختياراتكِ، وأنتِ تضيفين بيانات التوصيل بخصوصية تامة.</span></div><BadgeCheck /></div>}
    <section className="form-card checkout-details-card"><div className="form-card-head"><span><MapPin /></span><div><small>بيانات أساسية</small><h2>بيانات {ambassador ? "العميلة" : "التوصيل"}</h2></div></div><div className="form-grid"><label><span>الاسم الكامل *</span><input required autoComplete="name" placeholder="الاسم الثلاثي" value={customer.name} onChange={(e) => setCustomer({ ...customer, name: e.target.value })} /></label><label><span>رقم الهاتف *</span><input required autoComplete="tel" inputMode="tel" dir="ltr" placeholder="+218..." value={customer.phone} onChange={(e) => setCustomer({ ...customer, phone: e.target.value })} /></label><DeliveryLocationFields value={customer} onChange={setCustomer} /><label className="full"><span>العنوان بالتفصيل *</span><input required autoComplete="street-address" placeholder="الشارع، رقم المنزل، أقرب نقطة دالة" value={customer.address} onChange={(e) => setCustomer({ ...customer, address: e.target.value })} /></label></div>
    <div className="checkout-extras"><div className="cod-option"><span><CheckCircle2 /><b>الدفع عند الاستلام</b></span><small>ادفعي عند وصول الطلب</small></div><div className="block-label coupon-field"><span>كود الخصم <small>اختياري</small></span><div className="coupon-apply-row"><input dir="ltr" value={couponCode} onChange={(e) => { setCouponCode(e.target.value.toUpperCase()); if (appliedCouponCode) { setAppliedCouponCode(""); setCouponFeedback(""); } }} placeholder="أدخلي الكود" /><button type="button" onClick={appliedCouponCode ? removeCoupon : applyCoupon}>{appliedCouponCode ? "إزالة" : "تطبيق"}</button></div></div>{couponFeedback && <small className={pricing.coupon ? "coupon-valid" : "coupon-invalid"}>{pricing.coupon ? `${couponFeedback}${pricing.discount > 0 ? ` — وفّرتِ ${pricing.discount.toFixed(2)} د.ل` : ""}` : couponFeedback}</small>}<label className="block-label"><span>ملاحظة للطلب <small>اختياري</small></span><textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder="أي تفاصيل إضافية للتوصيل" /></label></div></section>
    {appearance.checkoutConfirmPosition === "afterCustomer" && confirmPanel}</div>
    <aside className="order-summary checkout-summary"><div className="summary-heading"><span><ShoppingBag /></span><div><small>{itemCount} {itemCount === 1 ? "قطعة" : "قطع"}</small><h2>مراجعة الطلب</h2></div></div><div className="checkout-items">{cart.map((item) => <div className="mini-line" key={item.lineId}><ProductImage src={item.imageUrl} alt={item.name} /><span><b>{item.name}</b><small>{item.quantity} × {item.price} د.ل</small>{ambassador && !isCustomerSharedCheckout && <em>عمولتك {lineCommission(item, commission).toFixed(2)} د.ل</em>}</span></div>)}</div><hr/><div><span>المجموع</span><strong>{pricing.subtotal.toFixed(2)} د.ل</strong></div>{pricing.discount > 0 && <div className="discount"><span>الخصم</span><strong>- {pricing.discount.toFixed(2)} د.ل</strong></div>}<div><span>التوصيل إلى {customer.city}</span><strong>{pricing.shippingCost.toFixed(2)} د.ل</strong></div>{ambassador && !isCustomerSharedCheckout && <div className="commission-summary compact"><span><CircleDollarSign /> عمولتك المتوقعة</span><strong>{expectedCommission.toFixed(2)} د.ل</strong></div>}<hr/><div className="summary-total"><span>الإجمالي</span><strong>{pricing.grandTotal.toFixed(2)} د.ل</strong></div>{appearance.checkoutConfirmPosition === "summary" && confirmPanel}</aside>
  </form></div>;
}

export default function CheckoutPage() {
  return <Suspense fallback={<div className="page-loading">جاري تجهيز صفحة الطلب...</div>}><CheckoutPageContent /></Suspense>;
}
