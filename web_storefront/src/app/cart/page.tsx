"use client";

import Link from "next/link";
import { ArrowLeft, BadgeCheck, CircleDollarSign, Minus, Plus, ShieldCheck, ShoppingBag, Trash2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { useAmbassador } from "@/components/ambassador-context";
import { AmbassadorShareButton } from "@/components/ambassador-share-button";
import { ProductImage } from "@/components/product-image";
import { cartItemMaximum, useStore } from "@/components/store-provider";
import { fetchProducts } from "@/lib/api";
import { commissionRate, lineCommission, totalCommission } from "@/lib/commission";
import { encodeSharedCart, readAmbassadorShare } from "@/lib/ambassador-share";
import { CartItem, Product } from "@/lib/types";

const cleanOption = (value: unknown): string =>
  String(value ?? "").trim().replace(/^[\s[\]"']+|[\s[\]"']+$/g, "").trim();

function currentMaximum(item: CartItem, product?: Product): number | undefined {
  if (product && item.size && product.sizeQuantities) {
    const wanted = cleanOption(item.size).toLocaleLowerCase();
    const match = Object.entries(product.sizeQuantities).find(([size]) => cleanOption(size).toLocaleLowerCase() === wanted);
    if (match) return Math.max(0, Math.floor(Number(match[1]) || 0));
  }
  if (product?.availableStock !== undefined) return Math.max(0, Math.floor(Number(product.availableStock) || 0));
  return cartItemMaximum(item);
}

export default function CartPage() {
  const { cart, total, updateQuantity, removeFromCart } = useStore();
  const { ambassador, commission } = useAmbassador();
  const [products, setProducts] = useState<Product[]>([]);
  useEffect(() => {
    const controller = new AbortController();
    fetchProducts(controller.signal).then(setProducts).catch(() => {});
    return () => controller.abort();
  }, []);
  const productsById = useMemo(() => new Map(products.map((product) => [product.id, product])), [products]);
  useEffect(() => {
    if (!products.length) return;
    for (const item of cart) {
      const maximum = currentMaximum(item, productsById.get(item.productId));
      if (maximum !== undefined && item.quantity > maximum) updateQuantity(item.lineId, maximum);
    }
  }, [cart, products.length, productsById, updateQuantity]);
  const itemCount = cart.reduce((sum, item) => sum + item.quantity, 0);
  const expectedCommission = totalCommission(cart, commission);
  const checkoutReferral = readAmbassadorShare()?.token || "";
  const checkoutHref = checkoutReferral
    ? `/checkout/?ref=${encodeURIComponent(checkoutReferral)}`
    : "/checkout/";

  return <div className="container inner-page cart-page">
    <header className="simple-page-head"><div><span>سلة التسوق</span><h1>اختياراتك جاهزة</h1><p>{cart.length ? `${itemCount} ${itemCount === 1 ? "قطعة" : "قطع"} في السلة` : "السلة في انتظار اختياراتك الجميلة"}</p></div>{cart.length > 0 && <Link href="/#collection">متابعة التسوق</Link>}</header>
    {cart.length === 0 ? <div className="empty-state"><ShoppingBag /><h3>سلتك فارغة</h3><p>اكتشفي تشكيلتنا وأضيفي ما تحبين.</p><Link className="primary-button" href="/#collection">ابدئي التسوق</Link></div>
      : <><div className="cart-layout"><div className="cart-main">{ambassador && <div className="ambassador-cart-banner"><BadgeCheck /><div><strong>حساب المندوب مفعّل</strong><span>تظهر عمولتك المتوقعة على كل قطعة قبل تأكيد الطلب.</span></div></div>}<div className="cart-lines">{cart.map((item) => {
        const maximum = currentMaximum(item, productsById.get(item.productId));
        const itemCommission = lineCommission(item, commission);
        const rate = commissionRate(item, commission);
        return <article className="cart-line" key={item.lineId}>
        <Link href={`/product/?id=${encodeURIComponent(item.productId)}`}><ProductImage src={item.imageUrl} alt={item.name} /></Link>
        <div className="cart-line-info"><div className="cart-line-title"><Link href={`/product/?id=${encodeURIComponent(item.productId)}`}><h3>{item.name}</h3></Link><button className="remove-button" onClick={() => removeFromCart(item.lineId)} aria-label="حذف"><Trash2 /></button></div><small>{[item.size && `المقاس: ${cleanOption(item.size)}`, item.length && `الطول: ${cleanOption(item.length)}`, item.color && `اللون: ${cleanOption(item.color)}`].filter(Boolean).join(" • ") || "قطعة جاهزة للطلب"}</small>{maximum !== undefined && <small className="stock-note">المتاح: {maximum} {maximum === 1 ? "قطعة" : "قطع"}</small>}<div className="cart-line-price"><strong>{(item.price * item.quantity).toFixed(2)} د.ل</strong>{ambassador && <span><CircleDollarSign /> عمولتك {itemCommission.toFixed(2)} د.ل <em>{rate}%</em></span>}</div></div>
        <div className="quantity"><button onClick={() => updateQuantity(item.lineId, item.quantity - 1)}><Minus /></button><span>{item.quantity}</span><button disabled={maximum !== undefined && item.quantity >= maximum} onClick={() => updateQuantity(item.lineId, item.quantity + 1)}><Plus /></button></div>
      </article>})}</div></div>
      <aside className="order-summary"><div className="summary-heading"><span><ShoppingBag /></span><div><small>ملخص بسيط</small><h2>طلبك</h2></div></div><div><span>عدد القطع</span><strong>{itemCount}</strong></div><div><span>المجموع الفرعي</span><strong>{total.toFixed(2)} د.ل</strong></div><div><span>التوصيل</span><span>يُحدد حسب المدينة</span></div>{ambassador && <div className="commission-summary"><span><CircleDollarSign /> عمولتك المتوقعة</span><strong>{expectedCommission.toFixed(2)} د.ل</strong><small>تُعتمد بعد نجاح التوصيل</small></div>}<hr /><div className="summary-total"><span>الإجمالي</span><strong>{total.toFixed(2)} د.ل</strong></div><div className="share-cart-panel"><BadgeCheck /><div><strong>{ambassador ? "قدّم لعميلتك تجربة AVEA الخاصة" : "شاركي سلتك كاملة"}</strong><small>{ambassador ? "أرسل اختياراتك باسمك كشريك معتمد، وستضيف العميلة بياناتها بنفسها." : "رابط واحد يفتح جميع اختياراتك بالمقاسات والكميات."}</small></div><AmbassadorShareButton title="اختيارات خاصة من AVEA Fashion" text={ambassador ? `اختيارات خاصة لكِ من شريك AVEA المعتمد ${ambassador.ambassadorName}. راجعي السلة وأكملي بيانات التوصيل بسهولة.` : "شاهدي سلة اختياراتي من AVEA Fashion."} label={ambassador ? "إرسال السلة باسمك" : "مشاركة السلة"} buildPath={(token) => `/shared-order/?${token ? `ref=${encodeURIComponent(token)}&` : ""}cart=${encodeSharedCart(cart)}`} /></div><Link className="primary-button checkout-link" href={checkoutHref}>إتمام الطلب <ArrowLeft /></Link><small className="summary-safe"><ShieldCheck /> الدفع عند الاستلام وبياناتك محفوظة بأمان</small></aside></div></>}
  </div>;
}
