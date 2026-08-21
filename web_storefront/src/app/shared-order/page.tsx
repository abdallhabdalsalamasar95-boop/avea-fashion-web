"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { BadgeCheck, CheckCircle2, LockKeyhole, Minus, Plus, ShoppingBag, Trash2, UserRoundCheck } from "lucide-react";
import { Suspense, useEffect, useMemo, useState } from "react";
import { ProductImage } from "@/components/product-image";
import { useStore } from "@/components/store-provider";
import { fetchAmbassadorShare, fetchProducts } from "@/lib/api";
import { clearAmbassadorShare, decodeSharedCart, saveAmbassadorShare, seedAmbassadorShareToken } from "@/lib/ambassador-share";
import { AmbassadorShare, CartItem, Product, SharedCartSelection } from "@/lib/types";

const clean = (value: unknown) => String(value ?? "").trim().toLocaleLowerCase();

function resolveItem(selection: SharedCartSelection, product: Product): CartItem | null {
  const optionExists = (selected: string | undefined, options: string[]) =>
    options.length === 0 || Boolean(selected && options.some((option) => clean(option) === clean(selected)));
  if (!optionExists(selection.size, product.sizes) || !optionExists(selection.length, product.lengths) || !optionExists(selection.color, product.colors)) return null;
  const sizeStock = selection.size
    ? Object.entries(product.sizeQuantities ?? {}).find(([size]) => clean(size) === clean(selection.size))?.[1]
    : undefined;
  const maximum = sizeStock ?? product.availableStock;
  if (product.outOfStock || maximum === 0) return null;
  const quantity = maximum === undefined ? selection.quantity : Math.min(selection.quantity, maximum);
  if (quantity < 1) return null;
  return {
    lineId: `${product.id}_${selection.size ?? ""}_${selection.length ?? ""}_${selection.color ?? ""}`,
    productId: product.id,
    productCode: product.productCode,
    name: product.name,
    price: product.price,
    imageUrl: product.imageUrl ?? product.imageUrls[0],
    category: product.category,
    tags: product.tags,
    size: selection.size,
    length: selection.length,
    color: selection.color,
    quantity,
    sizeQuantities: product.sizeQuantities,
    availableStock: product.availableStock,
    commissionPercent: product.commissionPercent,
  };
}

function SharedOrderReview() {
  const params = useSearchParams();
  const router = useRouter();
  const { replaceCart } = useStore();
  const token = params.get("ref") ?? "";
  const encodedCart = params.get("cart") ?? "";
  const selections = useMemo(() => decodeSharedCart(encodedCart), [encodedCart]);
  const [share, setShare] = useState<AmbassadorShare | null>(null);
  const [items, setItems] = useState<CartItem[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!selections.length) {
      setError("رابط الطلب غير مكتمل.");
      setLoading(false);
      return;
    }
    if (token.trim()) seedAmbassadorShareToken(token);
    const controller = new AbortController();
    Promise.all([token ? fetchAmbassadorShare(token, controller.signal) : Promise.resolve(null), fetchProducts(controller.signal)])
      .then(([verifiedShare, products]) => {
        const productMap = new Map(products.map((product) => [product.id, product]));
        const resolved = selections.flatMap((selection) => {
          const product = productMap.get(selection.productId);
          const item = product ? resolveItem(selection, product) : null;
          return item ? [item] : [];
        });
        if (resolved.length !== selections.length) throw new Error("تغيّر توفر أحد المنتجات أو خياراته. اطلبي من شريك Carmen Karla إرسال رابط جديد.");
        setShare(verifiedShare);
        if (verifiedShare) saveAmbassadorShare(verifiedShare);
        else clearAmbassadorShare();
        setProducts(products);
        setItems(resolved);
      })
      .catch((reason) => {
        if (!(reason instanceof DOMException && reason.name === "AbortError")) setError(reason instanceof Error ? reason.message : "تعذر فتح الطلب.");
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [selections, token]);

  const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const count = items.reduce((sum, item) => sum + item.quantity, 0);
  const productsById = useMemo(() => new Map(products.map((product) => [product.id, product])), [products]);

  const updateItem = (lineId: string, changes: Partial<CartItem>) => {
    setItems((current) => current.map((item) => {
      if (item.lineId !== lineId) return item;
      const next = { ...item, ...changes };
      const product = productsById.get(item.productId);
      const sizeStock = next.size
        ? Object.entries(product?.sizeQuantities ?? {}).find(([size]) => clean(size) === clean(next.size))?.[1]
        : undefined;
      const maximum = sizeStock ?? product?.availableStock;
      next.quantity = maximum === undefined ? Math.max(1, next.quantity) : Math.min(Math.max(1, next.quantity), maximum);
      next.lineId = `${next.productId}_${next.size ?? ""}_${next.length ?? ""}_${next.color ?? ""}`;
      return next;
    }));
  };

  const continueToDelivery = () => {
    if (!items.length) return;
    replaceCart(items);
    if (share) saveAmbassadorShare(share);
    else clearAmbassadorShare();
    router.push("/checkout/?shared=1");
  };

  if (loading) return <div className="page-loading">جاري تجهيز الطلب للمراجعة...</div>;
  if (error) return <div className="container inner-page"><div className="empty-state shared-order-error"><ShoppingBag /><h3>تعذر فتح الطلب</h3><p>{error}</p><Link className="primary-button" href="/">العودة للمتجر</Link></div></div>;

  return <div className="shared-order-page">
    <section className="shared-order-hero"><div className="container"><span><BadgeCheck /> {share ? "تجربة Carmen Karla الخاصة" : "سلة Carmen Karla مشتركة"}</span>{share && <div className="partner-hero-card"><i>CK</i><div><small>شريك Carmen Karla المعتمد</small><strong>{share.ambassadorName}</strong><em>نسّق لكِ هذه الاختيارات بعناية</em></div><BadgeCheck /></div>}<h1>{share ? "اختيارات صُمّمت لكِ" : "راجعي اختياراتكِ بهدوء"}</h1><p>{share ? <>راجعي القطع والمقاسات التي اختارها لكِ شريكنا <strong>{share.ambassadorName}</strong>، ثم أكملي بيانات التوصيل بكل خصوصية.</> : <>تمت مشاركة هذه السلة معكِ. راجعي المنتجات والمقاسات والكميات، ثم يمكنكِ إكمال الطلب ببياناتكِ.</>}</p><div className="shared-steps"><b className="active"><i>1</i> مراجعة الطلب</b><span></span><b><i>2</i> بيانات التوصيل</b><span></span><b><i>3</i> التأكيد</b></div></div></section>
    <div className="container shared-order-layout">
      <section className="shared-review-card"><header><div><small>اختياراتك</small><h2>{count} {count === 1 ? "قطعة" : "قطع"}</h2></div><CheckCircle2 /></header><div className="shared-review-lines">{items.map((item) => {
        const product = productsById.get(item.productId);
        return <article key={item.lineId}><ProductImage src={item.imageUrl} alt={item.name} /><div><div className="shared-line-title"><h3>{item.name}</h3><button onClick={() => setItems((current) => current.filter((line) => line.lineId !== item.lineId))} aria-label={`حذف ${item.name}`}><Trash2 /></button></div><div className="shared-line-options">{product && product.sizes.length > 0 && <label><span>المقاس</span><select value={item.size ?? ""} onChange={(event) => updateItem(item.lineId, { size: event.target.value })}>{product.sizes.map((size) => <option key={size} value={size} disabled={(product.sizeQuantities?.[size] ?? 1) < 1}>{size}</option>)}</select></label>}{product && product.lengths.length > 0 && <label><span>الطول</span><select value={item.length ?? ""} onChange={(event) => updateItem(item.lineId, { length: event.target.value })}>{product.lengths.map((length) => <option key={length}>{length}</option>)}</select></label>}{product && product.colors.length > 0 && <label><span>اللون</span><select value={item.color ?? ""} onChange={(event) => updateItem(item.lineId, { color: event.target.value })}>{product.colors.map((color) => <option key={color}>{color}</option>)}</select></label>}</div><div className="shared-line-quantity"><span>الكمية</span><div><button onClick={() => updateItem(item.lineId, { quantity: item.quantity - 1 })}><Minus /></button><b>{item.quantity}</b><button onClick={() => updateItem(item.lineId, { quantity: item.quantity + 1 })}><Plus /></button></div></div></div><strong>{(item.price * item.quantity).toFixed(2)} د.ل</strong></article>;
      })}</div>{items.length === 0 && <div className="shared-review-empty"><ShoppingBag /><p>حذفتِ جميع المنتجات.</p><Link href="/#collection">العودة للمتجر</Link></div>}</section>
      <aside className="shared-confirm-card"><UserRoundCheck /><small>الخطوة التالية لكِ وحدكِ</small><h2>بيانات توصيل خاصة وآمنة</h2><p>{share ? <>تولى شريك AVEA تنسيق اختياراتكِ، وأنتِ تضيفين اسمك وهاتفك وعنوانك بنفسكِ بكل خصوصية.</> : <>أضيفي اسمك وهاتفك وعنوانك بنفسكِ، ولن تظهر أي بيانات شخصية داخل رابط المشاركة.</>}</p><div><span>قيمة المنتجات</span><strong>{total.toFixed(2)} د.ل</strong></div><small className="delivery-later">تُضاف تكلفة التوصيل حسب المدينة</small><button className="primary-button" onClick={continueToDelivery} disabled={!items.length}>تأكيد الاختيارات — {total.toFixed(2)} د.ل</button><em><LockKeyhole /> الرابط آمن ولا يحتوي بياناتك الشخصية</em></aside>
    </div>
  </div>;
}

export default function SharedOrderPage() {
  return <Suspense fallback={<div className="page-loading">جاري التحميل...</div>}><SharedOrderReview /></Suspense>;
}
