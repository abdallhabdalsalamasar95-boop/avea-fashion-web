"use client";

import Link from "next/link";
import { ArrowRight, Check, ChevronLeft, ChevronRight, CircleDollarSign, Flame, Heart, Maximize2, Minus, Plus, Ruler, ShoppingBag, Sparkles, X, Zap } from "lucide-react";
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

// Weight ranges are calibrated for 160-170cm; height adjusts the result by one step.
const SIZE_CHART = [
  { size: "36", minWeight: 0, maxWeight: 50, weight: "45 - 50", bust: "82 - 85", waist: "64 - 67", hips: "90 - 93" },
  { size: "38", minWeight: 51, maxWeight: 56, weight: "51 - 56", bust: "86 - 89", waist: "68 - 71", hips: "94 - 97" },
  { size: "40", minWeight: 57, maxWeight: 63, weight: "57 - 63", bust: "90 - 93", waist: "72 - 75", hips: "98 - 101" },
  { size: "42", minWeight: 64, maxWeight: 71, weight: "64 - 71", bust: "94 - 97", waist: "76 - 79", hips: "102 - 105" },
  { size: "44", minWeight: 72, maxWeight: 80, weight: "72 - 80", bust: "98 - 101", waist: "80 - 83", hips: "106 - 109" },
  { size: "46", minWeight: 81, maxWeight: 89, weight: "81 - 89", bust: "102 - 105", waist: "84 - 87", hips: "110 - 113" },
  { size: "48", minWeight: 90, maxWeight: 98, weight: "90 - 98", bust: "106 - 109", waist: "88 - 91", hips: "114 - 117" },
  { size: "50", minWeight: 99, maxWeight: 999, weight: "99 - 108", bust: "110 - 113", waist: "92 - 95", hips: "118 - 121" },
];

function sizeFromBody(weightValue: string, heightValue: string): string {
  const weight = Number(weightValue);
  if (!Number.isFinite(weight) || weight < 35 || weight > 140) return "";
  let index = SIZE_CHART.findIndex((row) => weight <= row.maxWeight);
  if (index < 0) index = SIZE_CHART.length - 1;
  const height = Number(heightValue);
  if (Number.isFinite(height) && height >= 140 && height <= 200) {
    if (height < 158) index = Math.max(0, index - 1);
    else if (height > 175) index = Math.min(SIZE_CHART.length - 1, index + 1);
  }
  return SIZE_CHART[index].size;
}

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
  const [bodyWeight, setBodyWeight] = useState("");
  const [bodyHeight, setBodyHeight] = useState("");
  const { addToCart, isFavorite, toggleFavorite } = useStore();
  const { ambassador, commission } = useAmbassador();

  useEffect(() => {
    const controller = new AbortController();
    fetchProducts(controller.signal)
      .then((items) => {
        const found = items.find((item) => item.id === id) ?? null;
        setProduct(found);
        setImage(found?.imageUrl ?? found?.imageUrls[0] ?? "");
        const availableSizes = found?.sizes.filter((item: string) => (found.sizeQuantities?.[item] ?? 1) > 0) ?? [];
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
  const recommendedSize = sizeFromBody(bodyWeight, bodyHeight);
  const recommendedSizeAvailable = recommendedSize
    ? product.sizes.includes(recommendedSize) && (product.sizeQuantities?.[recommendedSize] ?? 1) > 0
    : undefined;
  const shareLabel = ambassador ? "شاركي مع عميلاتك" : "مشاركة المنتج";
  const shareText = ambassador
    ? `اختيار خاص لكِ من شريكة Carmen Karla المعتمدة ${ambassador.ambassadorName}. راجعي ${product.name} وأكملي طلبك بسهولة.`
    : `شاهدي ${product.name} على متجر Carmen Karla.`;

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
        <div className="purchase-panel">
          <div className="purchase-panel-top">
            <div className="quantity product-quantity"><button onClick={() => setQuantity(Math.max(1, quantity - 1))} aria-label="إنقاص"><Minus /></button><span>{quantity}</span><button disabled={maximumQuantity !== undefined && quantity >= maximumQuantity} onClick={() => setQuantity((current) => maximumQuantity !== undefined ? Math.min(maximumQuantity, current + 1) : current + 1)} aria-label="زيادة"><Plus /></button></div>
            <span className="purchase-total"><small>الإجمالي</small><strong>{(product.price * quantity).toFixed(0)} د.ل</strong></span>
          </div>
          <div className="purchase-row">
            <button className="primary-button buy-now-main" onClick={buyNow} disabled={incomplete || soldOut}><Zap /> اشتري الآن</button>
            <button className="primary-button add-main" onClick={add} disabled={incomplete || soldOut}>{added ? <><Check /> تمت الإضافة</> : <><ShoppingBag /> إضافة للسلة</>}</button>
            <button className={isFavorite(product.id) ? "icon-action wish-main active" : "icon-action wish-main"} onClick={() => toggleFavorite(product.id)} aria-label="إضافة للمفضلة" title="إضافة للمفضلة"><Heart fill={isFavorite(product.id) ? "currentColor" : "none"} /></button>
            <AmbassadorShareButton
              compact
              className="icon-action purchase-share"
              title={product.name}
              text={shareText}
              label={shareLabel}
              buildPath={(token) => `/product/?id=${encodeURIComponent(product.id)}${token ? `&ref=${encodeURIComponent(token)}` : ""}`}
            />
          </div>
        </div>
        <ul className="detail-benefits"><li><Check /> الدفع عند الاستلام</li><li><Check /> توصيل لجميع مدن ليبيا</li><li><Check /> خدمة عملاء لمتابعة طلبك</li></ul>
      </div>
    </div>

    {/* Mobile Sticky Bottom Purchase Bar */}
    <aside className="sticky-mobile-bar">
      <button className={isFavorite(product.id) ? "icon-action wish-main active" : "icon-action wish-main"} onClick={() => toggleFavorite(product.id)} aria-label="إضافة للمفضلة"><Heart fill={isFavorite(product.id) ? "currentColor" : "none"} /></button>
      <AmbassadorShareButton
        compact
        className="icon-action purchase-share"
        title={product.name}
        text={shareText}
        label={shareLabel}
        buildPath={(token) => `/product/?id=${encodeURIComponent(product.id)}${token ? `&ref=${encodeURIComponent(token)}` : ""}`}
      />
      <button className="primary-button add-main" onClick={add} disabled={incomplete || soldOut} aria-label="إضافة للسلة">{added ? <Check /> : <ShoppingBag />}<span>السلة</span></button>
      <button className="primary-button buy-now-main" onClick={buyNow} disabled={incomplete || soldOut}><Zap /><span>اشتري الآن · {(product.price * quantity).toFixed(0)} د.ل</span></button>
    </aside>

    {/* Size Guide Modal */}
    {showSizeGuide && <div className="modal-overlay" onClick={() => setShowSizeGuide(false)} role="dialog" aria-modal="true">
      <div className="size-modal-card" onClick={(e) => e.stopPropagation()}>
        <header><h3><Ruler /> دليل مقاسات Carmen Karla</h3><button onClick={() => setShowSizeGuide(false)} aria-label="إغلاق"><X /></button></header>

        <div className="size-finder">
          <p className="size-finder-title"><Sparkles /> احسبي مقاسكِ في ثانية</p>
          <div className="size-finder-inputs">
            <label><span>الوزن (كجم)</span><input type="number" inputMode="numeric" min={35} max={140} placeholder="60" value={bodyWeight} onChange={(e) => setBodyWeight(e.target.value)} /></label>
            <label><span>الطول (سم)</span><input type="number" inputMode="numeric" min={140} max={195} placeholder="165" value={bodyHeight} onChange={(e) => setBodyHeight(e.target.value)} /></label>
          </div>
          {recommendedSize
            ? <div className="size-finder-result">
                <Check />
                <span>مقاسكِ المقترح هو <strong>{recommendedSize}</strong>{recommendedSizeAvailable === false && <em> (غير متوفر حاليًا لهذا الموديل)</em>}</span>
                {recommendedSizeAvailable && <button type="button" onClick={() => { changeSize(recommendedSize); setShowSizeGuide(false); }}>اختيار المقاس</button>}
              </div>
            : <small className="size-finder-hint">أدخلي وزنكِ وطولكِ لعرض المقاس الأنسب لكِ.</small>}
        </div>

        <div className="size-table-wrap">
          <table>
            <thead><tr><th>المقاس</th><th>الوزن (كجم)</th><th>الصدر (سم)</th><th>الخصر (سم)</th><th>الأوراك (سم)</th></tr></thead>
            <tbody>
              {SIZE_CHART.map((row) => <tr key={row.size} className={recommendedSize === row.size ? "recommended" : ""}>
                <td><strong>{row.size}</strong></td>
                <td>{row.weight}</td>
                <td>{row.bust}</td>
                <td>{row.waist}</td>
                <td>{row.hips}</td>
              </tr>)}
            </tbody>
          </table>
        </div>
        <small className="size-guide-note">الأوزان تقديرية لطول 160 - 170 سم. للطول الأقل من 158 سم يُفضّل النزول مقاسًا، وللطول فوق 175 سم يُفضّل الصعود مقاسًا.</small>
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
