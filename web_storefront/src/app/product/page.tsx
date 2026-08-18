"use client";

import Link from "next/link";
import { ArrowRight, Check, ChevronLeft, ChevronRight, CircleDollarSign, Flame, Heart, Maximize2, Minus, Plus, Ruler, ShoppingBag, X, Zap } from "lucide-react";
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
  const [showSizeGuide, setShowSizeGuide] = useState(false);
  const [showLightbox, setShowLightbox] = useState(false);
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
  const galleryIndex = gallery.indexOf(image) >= 0 ? gallery.indexOf(image) : 0;
  const nextImage = () => gallery.length > 1 && setImage(gallery[(galleryIndex + 1) % gallery.length]);
  const prevImage = () => gallery.length > 1 && setImage(gallery[(galleryIndex - 1 + gallery.length) % gallery.length]);
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
        <div className="main-image" onClick={() => setShowLightbox(true)} role="button" tabIndex={0} aria-label="عرض الصورة بملء الشاشة">
          <ProductImage src={image} alt={product.name} />
          <span className="lightbox-trigger" title="تكبير الصورة"><Maximize2 /></span>
        </div>
        {gallery.length > 1 && <div className="gallery-dots">{gallery.map((src, idx) => <button key={idx} className={src === image ? "active" : ""} onClick={() => setImage(src)} aria-label={`صورة ${idx + 1}`} />)}</div>}
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
        {product.sizes.length > 0 && <Option title="المقاس" items={product.sizes} value={size} onChange={changeSize} quantities={product.sizeQuantities} onOpenSizeGuide={() => setShowSizeGuide(true)} />}
        {selectedSizeStock !== undefined && selectedSizeStock > 0 && selectedSizeStock <= 3 && <div className="urgency-badge"><Flame /><span>متبقي {selectedSizeStock === 1 ? "قطعة واحدة فقط" : `${selectedSizeStock} قطع فقط`} من هذا المقاس!</span></div>}
        {!size && !soldOut && product.availableStock !== undefined && product.availableStock > 0 && product.availableStock <= 3 && <div className="urgency-badge"><Flame /><span>كمية محدودة جدًا متوفرة الآن!</span></div>}
        {product.lengths.length > 0 && <Option title="الطول" items={product.lengths} value={length} onChange={setLength} />}
        {product.colors.length > 0 && <Option title="اللون" items={product.colors} value={color} onChange={setColor} />}
        <div className="product-secondary-actions">
          <div className="quantity product-quantity"><button onClick={() => setQuantity(Math.max(1, quantity - 1))}><Minus /></button><span>{quantity}</span><button disabled={maximumQuantity !== undefined && quantity >= maximumQuantity} onClick={() => setQuantity((current) => maximumQuantity !== undefined ? Math.min(maximumQuantity, current + 1) : current + 1)}><Plus /></button></div>
          <button className={isFavorite(product.id) ? "wish-main active" : "wish-main"} onClick={() => toggleFavorite(product.id)} aria-label="إضافة للمفضلة"><Heart fill={isFavorite(product.id) ? "currentColor" : "none"} /></button>
        </div>
        <div className="purchase-row">
          <button className="primary-button add-main" onClick={add} disabled={incomplete || soldOut}>{added ? <><Check /> تم</> : <><ShoppingBag /> إضافة للسلة</>}</button>
          <button className="primary-button buy-now-main" onClick={buyNow} disabled={incomplete || soldOut}><Zap /> اشتري الآن</button>
          <AmbassadorShareButton
            className="detail-share-action purchase-share"
            title={product.name}
            text={ambassador ? `اختيار خاص لكِ من شريكة Carmen Karla المعتمدة ${ambassador.ambassadorName}. راجعي ${product.name} وأكملي طلبك بسهولة.` : `شاهدي ${product.name} على متجر Carmen Karla.`}
            label={ambassador ? "شاركي مع عميلاتك" : "مشاركة"}
            buildPath={(token) => `/product/?id=${encodeURIComponent(product.id)}${token ? `&ref=${encodeURIComponent(token)}` : ""}`}
          />
        </div>
        <ul className="detail-benefits"><li><Check /> الدفع عند الاستلام</li><li><Check /> توصيل لجميع مدن ليبيا</li><li><Check /> خدمة عملاء لمتابعة طلبك</li></ul>
      </div>
    </div>

    {/* Mobile Sticky Bottom Purchase Bar */}
    <aside className="sticky-mobile-bar">
      <div className="sticky-bar-price"><strong>{product.price} د.ل</strong><small>{product.name}</small></div>
      <div className="sticky-bar-actions">
        <button className="primary-button buy-now-main" onClick={buyNow} disabled={incomplete || soldOut}><Zap /> اشتري الآن</button>
        <button className="primary-button add-main" onClick={add} disabled={incomplete || soldOut}><ShoppingBag /> السلة</button>
      </div>
    </aside>

    {/* Size Guide Modal */}
    {showSizeGuide && <div className="modal-overlay" onClick={() => setShowSizeGuide(false)} role="dialog" aria-modal="true">
      <div className="size-modal-card" onClick={(e) => e.stopPropagation()}>
        <header><h3><Ruler /> دليل مقاسات Carmen Karla</h3><button onClick={() => setShowSizeGuide(false)} aria-label="إغلاق"><X /></button></header>
        <div className="size-table-wrap">
          <table>
            <thead><tr><th>المقاس</th><th>الصدر (سم)</th><th>الخصر (سم)</th><th>الأوراك (سم)</th></tr></thead>
            <tbody>
              <tr><td>38</td><td>86 - 89</td><td>68 - 71</td><td>94 - 97</td></tr>
              <tr><td>40</td><td>90 - 93</td><td>72 - 75</td><td>98 - 101</td></tr>
              <tr><td>42</td><td>94 - 97</td><td>76 - 79</td><td>102 - 105</td></tr>
              <tr><td>44</td><td>98 - 101</td><td>80 - 83</td><td>106 - 109</td></tr>
              <tr><td>46</td><td>102 - 105</td><td>84 - 87</td><td>110 - 113</td></tr>
              <tr><td>48</td><td>106 - 109</td><td>88 - 91</td><td>114 - 117</td></tr>
              <tr><td>50</td><td>110 - 113</td><td>92 - 95</td><td>118 - 121</td></tr>
            </tbody>
          </table>
        </div>
        <small className="size-guide-note">قياسات دقيقة بالسنتمتر لتسهيل الاختيار المثالي.</small>
      </div>
    </div>}

    {/* Lightbox Modal */}
    {showLightbox && <div className="lightbox-overlay" onClick={() => setShowLightbox(false)} role="dialog" aria-modal="true">
      <button className="lightbox-close" onClick={() => setShowLightbox(false)} aria-label="إغلاق"><X /></button>
      {gallery.length > 1 && <button className="lightbox-nav prev" onClick={(e) => { e.stopPropagation(); prevImage(); }} aria-label="الصورة السابقة"><ChevronRight /></button>}
      <img src={image} alt={product.name} className="lightbox-img" onClick={(e) => e.stopPropagation()} />
      {gallery.length > 1 && <button className="lightbox-nav next" onClick={(e) => { e.stopPropagation(); nextImage(); }} aria-label="الصورة التالية"><ChevronLeft /></button>}
    </div>}
  </div>;
}

function Option({ title, items, value, onChange, quantities, onOpenSizeGuide }: { title: string; items: string[]; value: string; onChange: (value: string) => void; quantities?: Record<string, number>; onOpenSizeGuide?: () => void }) {
  const availableItems = items.filter((item) => !(quantities && Object.hasOwn(quantities, item) && quantities[item] === 0));
  if (title === "المقاس" && availableItems.length === 0) return <div className="option-group option-unavailable"><label>{title}</label><p>هذا الموديل غير متوفر حاليًا.</p></div>;
  return <div className="option-group">
    <div className="option-group-head">
      <label>{title}</label>
      {title === "المقاس" && onOpenSizeGuide && <button type="button" className="size-guide-link" onClick={onOpenSizeGuide}><Ruler /> جدول المقاسات</button>}
    </div>
    <div>{items.map((item) => {
    const quantity = quantities && Object.hasOwn(quantities, item) ? quantities[item] : undefined;
    const unavailable = quantity === 0;
    if (unavailable) return null;
    return <button className={value === item ? "active" : ""} onClick={() => onChange(item)} key={item}>
      <strong>{item}</strong>
    </button>;
  })}</div></div>;
}

export default function ProductPage() {
  return <Suspense fallback={<div className="page-loading">جاري التحميل...</div>}><ProductDetails /></Suspense>;
}
