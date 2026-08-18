"use client";

import Link from "next/link";
import { ArrowLeft, ChevronDown, RefreshCw, Search, ShieldCheck, Sparkles, Truck } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { ProductCard } from "@/components/product-card";
import { fetchAppContent, fetchProducts } from "@/lib/api";
import { AppContent, Product } from "@/lib/types";
import { useSiteAppearance } from "@/components/site-appearance-provider";

export default function Home() {
  const appearance = useSiteAppearance();
  const [products, setProducts] = useState<Product[]>([]);
  const [content, setContent] = useState<AppContent>({});
  const [query, setQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [sort, setSort] = useState("featured");
  const [inStockOnly, setInStockOnly] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    Promise.allSettled([fetchProducts(controller.signal), fetchAppContent(controller.signal)])
      .then(([catalog, marketing]) => {
        if (catalog.status === "fulfilled") setProducts(catalog.value);
        else setError("تعذر تحميل المنتجات الآن. قد يستغرق تشغيل الخادم لحظات.");
        if (marketing.status === "fulfilled") setContent(marketing.value);
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [retry]);

  const categories = useMemo(() => Array.from(new Set(products.map((p) => p.category).filter(Boolean) as string[])), [products]);
  const shown = useMemo(() => products.filter((product) => {
    const term = query.trim().toLocaleLowerCase("ar");
    const matchesQuery = !term || `${product.name} ${product.category ?? ""} ${product.tags ?? ""}`.toLocaleLowerCase("ar").includes(term);
    const matchesStock = !inStockOnly || (!product.outOfStock && (product.availableStock ?? 0) > 0);
    return matchesQuery && matchesStock;
  }).sort((a, b) => {
    if (sort === "price-low") return a.price - b.price;
    if (sort === "price-high") return b.price - a.price;
    if (sort === "rating") return (b.rating ?? 0) - (a.rating ?? 0);
    if (sort === "newest") return (b.createdAt ?? 0) - (a.createdAt ?? 0);
    return Number(Boolean(b.imageUrl)) - Number(Boolean(a.imageUrl));
  }), [products, query, inStockOnly, sort]);
  const newestProducts = useMemo(() => [...products].sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0)).slice(0, 10), [products]);
  const bestSellingProducts = useMemo(() => [...products].sort((a, b) =>
    (b.soldPieces ?? 0) - (a.soldPieces ?? 0) || (b.createdAt ?? 0) - (a.createdAt ?? 0)
  ).slice(0, 10), [products]);

  const offer = content.offers?.items?.find((item) => item.enabled !== false)?.text;
  const managedBanner = content.websiteHome?.banner;
  const bannerImage = managedBanner?.imageUrl?.trim();
  const bannerVisible = managedBanner?.enabled !== false && Boolean(bannerImage);
  const sectionBanner = content.websiteHome?.sectionBanner;
  const sectionBannerImage = sectionBanner?.imageUrl?.trim();
  const sectionBannerVisible = sectionBanner?.enabled !== false && Boolean(sectionBannerImage);
  const categoryShowcase = (content.websiteHome?.categories ?? [])
    .filter((item) => item.enabled !== false && item.title.trim())
    .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));

  return (
    <>
      {bannerVisible && <section className="managed-hero">
        <a href={managedBanner?.linkUrl?.trim() || "#collection"} aria-label={managedBanner?.altText || "تسوّقي من كارمن كارلا"}>
          <img src={bannerImage} alt={managedBanner?.altText || "بانر كارمن كارلا"} />
        </a>
      </section>}

      {appearance.showHomepageCategories && categoryShowcase.length > 0 && <section className="category-showcase container" id="categories">
        <div className="category-cards">
          {categoryShowcase.map((item) => <Link className="category-link" key={item.id} href={`/category/?name=${encodeURIComponent(item.productCategoryFilter?.trim() || item.title)}&title=${encodeURIComponent(item.title)}`}>
            {item.imageUrl ? <img src={item.imageUrl} alt={item.title} loading="lazy" /> : <div className="category-placeholder">Carmen Karla</div>}
            <span><strong>{item.title}</strong></span>
          </Link>)}
        </div>
      </section>}

      {appearance.showOffersStrip && offer && <aside className="offer-strip"><Sparkles /><span>{offer}</span></aside>}

      {appearance.showNewestSection && !loading && newestProducts.length > 0 && <section className="home-product-section container" aria-labelledby="newest-products-title">
        <div className="home-rail-heading">
          <div><span>وصل حديثًا</span><h2 id="newest-products-title">الأحدث</h2><p>أجدد الموديلات التي وصلت إلى كارمن كارلا.</p></div>
          <small>اسحبي لليسار <ArrowLeft /></small>
        </div>
        <div className="home-product-rail">
          {newestProducts.map((product) => <ProductCard product={product} key={`new-${product.id}`} />)}
        </div>
      </section>}

      {sectionBannerVisible && <section className={`managed-section-banner section-banner-${sectionBanner?.widthMode ?? "full"} section-banner-spacing-${sectionBanner?.spacing ?? "tight"} section-banner-height-${sectionBanner?.height ?? "medium"}${sectionBanner?.widthMode === "container" ? " container" : ""}`}>
        <a href={sectionBanner?.linkUrl?.trim() || "#collection"} aria-label={sectionBanner?.altText || "تسوّقي أحدث تشكيلات كارمن كارلا"}>
          <img src={sectionBannerImage} alt={sectionBanner?.altText || "بانر أحدث المنتجات والأكثر مبيعًا"} loading="lazy" />
        </a>
      </section>}

      {appearance.showBestSellingSection && !loading && bestSellingProducts.length > 0 && <section className="home-product-section container" aria-labelledby="best-products-title">
        <div className="home-rail-heading">
          <div><span>اختيار العميلات</span><h2 id="best-products-title">الأكثر مبيعًا</h2><p>الموديلات الأعلى طلبًا من عميلات كارمن كارلا.</p></div>
          <small>اسحبي لليسار <ArrowLeft /></small>
        </div>
        <div className="home-product-rail">
          {bestSellingProducts.map((product) => <ProductCard product={product} key={`best-${product.id}`} />)}
        </div>
      </section>}

      <section className="collection container" id="collection">
        <div className="section-heading">
          <div><h2>كل المنتجات</h2></div>
          <a className="view-all" href="#catalog-controls">تصفّحي الكل <ArrowLeft /></a>
        </div>
        <div className="catalog-sticky-bar">
          <div className="catalog-controls" id="catalog-controls">
            <div className={`floating-search ${searchOpen ? "open" : ""}`}>
              {searchOpen && <input autoFocus value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ابحثي عن منتج..." aria-label="البحث عن منتج" />}
              <button type="button" className="floating-search-button" onClick={() => setSearchOpen((value) => !value)} aria-label={searchOpen ? "إغلاق البحث" : "البحث عن منتج"}><Search /></button>
            </div>
          </div>
          <div className="category-list">
            <a className="active" href="#catalog-controls">الكل</a>
            {categories.map((item) => <Link key={item} href={`/category/?name=${encodeURIComponent(item)}`}>{item}</Link>)}
          </div>
        </div>
        <div className="catalog-toolbar">
          <p><strong>{shown.length}</strong> منتج</p>
          <div>
            <label className="stock-toggle"><input type="checkbox" checked={inStockOnly} onChange={(event) => setInStockOnly(event.target.checked)} /><span /> المتوفر فقط</label>
            <label className="sort-select"><span>ترتيب حسب</span><select value={sort} onChange={(event) => setSort(event.target.value)}><option value="featured">المقترحة</option><option value="newest">الأحدث</option><option value="price-low">السعر: الأقل أولًا</option><option value="price-high">السعر: الأعلى أولًا</option><option value="rating">الأعلى تقييمًا</option></select><ChevronDown /></label>
          </div>
        </div>

        {loading ? <div className="product-grid">{Array.from({ length: 8 }, (_, i) => <div className="skeleton-card" key={i}><div /><span /><small /></div>)}</div>
          : error && products.length === 0 ? <div className="empty-state"><h3>نرتّب الرفوف الآن</h3><p>{error}</p><button className="secondary-button" onClick={() => setRetry((v) => v + 1)}><RefreshCw /> إعادة المحاولة</button></div>
          : shown.length === 0 ? <div className="empty-state"><h3>لا توجد نتائج</h3><p>جرّبي كلمة بحث أو تصنيفًا آخر.</p></div>
          : <div className="product-grid">{shown.map((product) => <ProductCard product={product} key={product.id} />)}</div>}
      </section>

      <section className="benefits container">
        <div><Truck /><span><strong>توصيل لكل ليبيا</strong><small>بسرعة وأمان</small></span></div>
        <div><ShieldCheck /><span><strong>تسوّق آمن</strong><small>الدفع عند الاستلام</small></span></div>
        <div><Sparkles /><span><strong>اختيارات مميزة</strong><small>تشكيلات متجددة</small></span></div>
      </section>

      <section className="about" id="about"><div className="container"><span>Carmen Karla</span><h2>اختيارات صنعت لتتميّز</h2></div></section>
    </>
  );
}

