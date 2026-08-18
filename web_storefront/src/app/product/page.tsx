"use client";

import Link from "next/link";
import { ArrowRight, Check, CircleDollarSign, Heart, Minus, Plus, ShoppingBag, Zap } from "lucide-react";
import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAmbassador } from "@/components/ambassador-context";
import { AmbassadorShareButton } from "@/components/ambassador-share-button";
import { ProductImage } from "@/components/product-image";
import { useStore } from "@/components/store-provider";
import { fetchAmbassadorShare, fetchProducts } from "@/lib/api";
import { saveAmbassadorShare } from "@/lib/ambassador-share";
import { commissionRate, lineCommission } from "@/lib/commission";
import { animateProductToCart } from "@/lib/cart-animation";
import { Product } from "@/lib/types";

function ProductDetails() {
  const searchParams = useSearchParams();
  const id = searchParams.get("id");
  const referralToken = searchParams.get("ref");
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [image, setImage] = useState("");
  const [size, setSize] = useState("");
  const [length, setLength] = useState("");
  const [color, setColor] = useState("");
  const [quantity, setQuantity] = useState(1);
  const [added, setAdded] = useState(false);
  const [sharedBy, setSharedBy] = useState("");
  const { addToCart, isFavorite, toggleFavorite } = useStore();
  const { ambassador, commission } = useAmbassador();

  useEffect(() => {
    const controller = new AbortController();
    fetchProducts(controller.signal)
      .then((items) => {
        const found = items.find((item) => item.id === id) ?? null;
        setProduct(found);
        setImage(found?.imageUrl ?? found?.imageUrls[0] ?? "");
        const availableSizes = found?.sizes.filter((item) => (found.sizeQuantities?.[item] ?? 1) > 0) ?? [];
        if (availableSizes.length === 1) setSize(availableSizes[0]);
        if (found?.lengths.length === 1) setLength(found.lengths[0]);
        if (found?.colors.length === 1) setColor(found.colors[0]);
      })
      .catch((reason: unknown) => {
        if (!(reason instanceof DOMException && reason.name === "AbortError")) setProduct(null);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [id]);

  useEffect(() => {
    if (!referralToken) return;
    const controller = new AbortController();
    fetchAmbassadorShare(referralToken, controller.signal)
      .then((share) => { saveAmbassadorShare(share); setSharedBy(share.ambassadorName); })
      .catch(() => setSharedBy(""));
    return () => controller.abort();
  }, [referralToken]);

  if (loading) return <div className="page-loading">جاري تحميل تفاصيل القطعة...</div>;
  if (!product) return <div className="empty-state standalone"><h3>المنتج غير موجود</h3><Link className="secondary-button" href="/">العودة للمتجر</Link></div>;
  const gallery = product.imageUrls.length ? product.imageUrls : product.imageUrl ? [product.imageUrl] : [];
  const incomplete = (product.sizes.length > 0 && !size) || (product.lengths.length > 0 && !length) || (product.colors.length > 0 && !color);
  const soldOut = product.outOfStock || product.availableStock === 0;
  const selectedSizeStock = size && product.sizeQuantities && Object.hasOwn(product.sizeQuantities, size)
    ? product.sizeQuantities[size]
    : undefined;
  const maximumQuantity = selectedSizeStock ?? product.availableStock;

  const changeSize = (nextSize: string) => {
    setSize(nextSize);
    const stock = product.sizeQuantities?.[nextSize];
    if (stock !== undefined) setQuantity((current) => Math.min(current, Math.max(1, stock)));
  };

  const add = (event: React.MouseEvent<HTMLButtonElement>) => {
    if (incomplete || soldOut) return;
    addToCart({
      lineId: `${product.id}_${size}_${length}_${color}`,
      productId: product.id, productCode: product.productCode, name: product.name, price: product.price,
      imageUrl: image, category: product.category, tags: product.tags,
      size, length, color, quantity, commissionPercent: product.commissionPercent,
      sizeQuantities: product.sizeQuantities, availableStock: product.availableStock,
    });
    animateProductToCart(event.currentTarget);
    setAdded(true);
    window.setTimeout(() => setAdded(false), 2200);
  };

  const buyNow = () => {
    if (incomplete || soldOut) return;
    sessionStorage.setItem("carmen-karla.direct-checkout.v1", JSON.stringify([{
      lineId: `${product.id}_${size}_${length}_${color}`,
      productId: product.id, productCode: product.productCode, name: product.name, price: product.price,
      imageUrl: image, category: product.category, tags: product.tags,
      size, length, color, quantity, commissionPercent: product.commissionPercent,
      sizeQuantities: product.sizeQuantities, availableStock: product.availableStock,
    }]));
    window.location.href = "/checkout/?direct=1";
  };

  return <div className="container detail-page">
    <Link className="back-link" href="/"><ArrowRight /> العودة للتشكيلة</Link>
    <div className="detail-grid">
      <div className="gallery">
        <div className="main-image"><ProductImage src={image} alt={product.name} /></div>
        {gallery.length > 1 && <div className="thumbs">{gallery.map((src) => <button className={src === image ? "active" : ""} onClick={() => setImage(src)} key={src}><ProductImage src={src} alt={product.name} /></button>)}</div>}
      </div>
      <div className="detail-info">
        {sharedBy && <div className="shared-product-note partner-signature"><span className="partner-mark">CK</span><span><small>اختيار خاص من شريكة Carmen Karla المعتمدة</small><strong>{sharedBy}</strong><em>اختارت لكِ هذه القطعة بعناية</em></span><Check /></div>}
        <span className="detail-category">{product.category}</span>
        <h1>{product.name}</h1>
        {product.productCode && <small>رمز المنتج: {product.productCode}</small>}
        <div className="detail-price"><strong>{product.price} د.ل</strong>{product.oldPrice && product.oldPrice > product.price && <del>{product.oldPrice} د.ل</del>}</div>
        {ambassador && !referralToken && <div className="detail-commission"><CircleDollarSign /><span><small>عمولتك على القطعة</small><strong>{lineCommission({ ...product, quantity: 1 }, commission).toFixed(2)} د.ل</strong></span><em>{commissionRate(product, commission)}%</em></div>}
        {product.description && <p className="description">{product.description}</p>}
        {product.sizes.length > 0 && <Option title="المقاس" items={product.sizes} value={size} onChange={changeSize} quantities={product.sizeQuantities} />}
        {product.lengths.length > 0 && <Option title="الطول" items={product.lengths} value={length} onChange={setLength} />}
        {product.colors.length > 0 && <Option title="اللون" items={product.colors} value={color} onChange={setColor} />}
        <div className="purchase-row">
          <div className="quantity"><button onClick={() => setQuantity(Math.max(1, quantity - 1))}><Minus /></button><span>{quantity}</span><button disabled={maximumQuantity !== undefined && quantity >= maximumQuantity} onClick={() => setQuantity((current) => maximumQuantity !== undefined ? Math.min(maximumQuantity, current + 1) : current + 1)}><Plus /></button></div>
          <button className="primary-button add-main" onClick={add} disabled={incomplete || soldOut}>{added ? <><Check /> تمت الإضافة</> : <><ShoppingBag /> {soldOut ? "نفد المخزون" : incomplete ? "اختاري الخيارات" : "أضيفي للسلة"}</>}</button>
          <button className="primary-button buy-now-main" onClick={buyNow} disabled={incomplete || soldOut}><Zap /> {soldOut ? "نفد المخزون" : incomplete ? "اختاري الخيارات" : "اطلبي الآن"}</button>
          <button className={isFavorite(product.id) ? "wish-main active" : "wish-main"} onClick={() => toggleFavorite(product.id)}><Heart fill={isFavorite(product.id) ? "currentColor" : "none"} /></button>
        </div>
        <AmbassadorShareButton
          className="detail-share-action"
          title={product.name}
          text={ambassador ? `اختيار خاص لكِ من شريكة Carmen Karla المعتمدة ${ambassador.ambassadorName}. راجعي ${product.name} وأكملي طلبك بسهولة.` : `شاهدي ${product.name} على متجر Carmen Karla.`}
          label={ambassador ? "إرسال المنتج للزبونة" : "مشاركة المنتج"}
          buildPath={(token) => `/product/?id=${encodeURIComponent(product.id)}${token ? `&ref=${encodeURIComponent(token)}` : ""}`}
        />
        <ul className="detail-benefits"><li><Check /> الدفع عند الاستلام</li><li><Check /> توصيل لجميع مدن ليبيا</li><li><Check /> خدمة عملاء لمتابعة طلبك</li></ul>
      </div>
    </div>
  </div>;
}

function Option({ title, items, value, onChange, quantities }: { title: string; items: string[]; value: string; onChange: (value: string) => void; quantities?: Record<string, number> }) {
  return <div className="option-group"><label>{title}</label><div>{items.map((item) => {
    const quantity = quantities && Object.hasOwn(quantities, item) ? quantities[item] : undefined;
    const unavailable = quantity === 0;
    return <button className={value === item ? "active" : ""} onClick={() => onChange(item)} disabled={unavailable} key={item}>
      <strong>{item}</strong>
    </button>;
  })}</div></div>;
}

export default function ProductPage() {
  return <Suspense fallback={<div className="page-loading">جاري التحميل...</div>}><ProductDetails /></Suspense>;
}
