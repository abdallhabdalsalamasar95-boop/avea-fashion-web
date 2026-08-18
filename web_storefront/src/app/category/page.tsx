"use client";

import Link from "next/link";
import { ArrowRight, Check, ChevronUp, RefreshCw, Search, SlidersHorizontal, X } from "lucide-react";
import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ProductCard } from "@/components/product-card";
import { fetchAppContent, fetchProducts } from "@/lib/api";
import { AppContent, Product } from "@/lib/types";

const cleanCategory = (value: string) => value.trim().replace(/\s+/g, " ").toLocaleLowerCase("ar");

function CategoryCollection() {
  const searchParams = useSearchParams();
  const requestedCategory = searchParams.get("name")?.trim() ?? "";
  const displayTitle = searchParams.get("title")?.trim() || requestedCategory || "القسم";
  const [products, setProducts] = useState<Product[]>([]);
  const [content, setContent] = useState<AppContent>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);
  const [sheet, setSheet] = useState<"filters" | "categories" | null>(null);
  const [size, setSize] = useState("");
  const [price, setPrice] = useState<"all" | "under300" | "300to500" | "over500">("all");
  const [inStockOnly, setInStockOnly] = useState(false);
  const [query, setQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [sort, setSort] = useState<"newest" | "priceLow" | "priceHigh">("newest");
  const dragStartY = useRef<number | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    Promise.allSettled([fetchProducts(controller.signal), fetchAppContent(controller.signal)])
      .then(([catalog, marketing]) => {
        if (catalog.status === "rejected") throw catalog.reason;
        setProducts(catalog.value);
        if (marketing.status === "fulfilled") setContent(marketing.value);
      })
      .catch(() => setError("تعذر تحميل منتجات القسم الآن. جرّبي مرة أخرى بعد لحظات."))
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [retry]);

  useEffect(() => {
    if (!sheet) return;
    const close = (event: KeyboardEvent) => { if (event.key === "Escape") setSheet(null); };
    document.body.classList.add("category-sheet-open");
    window.addEventListener("keydown", close);
    return () => {
      document.body.classList.remove("category-sheet-open");
      window.removeEventListener("keydown", close);
    };
  }, [sheet]);

  useEffect(() => {
    setSize("");
    setPrice("all");
    setInStockOnly(false);
    setSort("newest");
    setQuery("");
    setSearchOpen(false);
    setSheet(null);
  }, [requestedCategory]);

  const categoryProducts = useMemo(() => {
    const wanted = cleanCategory(requestedCategory);
    return products.filter((product) => cleanCategory(product.category ?? "") === wanted);
  }, [products, requestedCategory]);
  const availableSizes = useMemo(() => Array.from(new Set(categoryProducts.flatMap((product) => product.sizes).filter(Boolean))), [categoryProducts]);
  const visibleProducts = useMemo(() => categoryProducts.filter((product) => {
    const term = query.trim().toLocaleLowerCase("ar");
    if (term && !`${product.name} ${product.tags ?? ""}`.toLocaleLowerCase("ar").includes(term)) return false;
    if (size && !product.sizes.includes(size)) return false;
    if (inStockOnly && (product.outOfStock || Number(product.availableStock ?? 0) <= 0)) return false;
    if (price === "under300" && product.price >= 300) return false;
    if (price === "300to500" && (product.price < 300 || product.price > 500)) return false;
    if (price === "over500" && product.price <= 500) return false;
    return true;
  }).sort((a, b) => {
    if (sort === "priceLow") return a.price - b.price;
    if (sort === "priceHigh") return b.price - a.price;
    return (b.createdAt ?? 0) - (a.createdAt ?? 0);
  }), [categoryProducts, inStockOnly, price, query, size, sort]);
  const managedCategories = useMemo(() => (content.websiteHome?.categories ?? [])
    .filter((item) => item.enabled !== false && item.title?.trim())
    .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0)), [content]);
  const activeFilterCount = Number(Boolean(size)) + Number(price !== "all") + Number(inStockOnly) + Number(sort !== "newest");
  const resetFilters = () => { setSize(""); setPrice("all"); setInStockOnly(false); setSort("newest"); };
  const finishCategoryDrag = (clientY: number) => {
    if (dragStartY.current !== null && dragStartY.current - clientY > 24) setSheet("categories");
    dragStartY.current = null;
  };

  return (
    <main className="category-page container category-products-only">
      <header className="category-simple-head">
        <h1>{displayTitle}</h1>
        <Link href="/"><ArrowRight /> رجوع</Link>
      </header>

      {loading ? <div className="product-grid">{Array.from({ length: 8 }, (_, index) => <div className="skeleton-card" key={index}><div /><span /><small /></div>)}</div>
        : error ? <div className="empty-state"><h3>نرتّب المجموعة الآن</h3><p>{error}</p><button className="secondary-button" onClick={() => setRetry((value) => value + 1)}><RefreshCw /> إعادة المحاولة</button></div>
        : !requestedCategory || categoryProducts.length === 0 ? <div className="empty-state category-empty"><h3>لا توجد منتجات في هذا القسم حاليًا</h3><Link className="primary-button" href="/">رجوع للرئيسية</Link></div>
        : visibleProducts.length === 0 ? <div className="empty-state category-empty"><h3>لا توجد نتائج بهذه الفلترة</h3><button className="secondary-button" onClick={resetFilters}>عرض كل المنتجات</button></div>
        : <div className="product-grid category-product-grid">{visibleProducts.map((product) => <ProductCard product={product} key={product.id} />)}</div>}

      {!loading && !error && categoryProducts.length > 0 && <div className="category-floating-tools" aria-label="أدوات القسم">
        {searchOpen && <div className="category-floating-search"><input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ابحثي عن منتج..." aria-label="البحث داخل القسم" /></div>}
        <button className={`category-search-button ${searchOpen ? "active" : ""}`} type="button" onClick={() => setSearchOpen((value) => !value)} aria-label={searchOpen ? "إغلاق البحث" : "البحث عن منتج"}><Search /></button>
        <button className={activeFilterCount ? "active" : ""} type="button" onClick={() => setSheet("filters")} aria-label="فتح الفلترة"><SlidersHorizontal />{activeFilterCount > 0 && <b>{activeFilterCount}</b>}</button>
        {managedCategories.length > 0 && <button className="category-pull-handle" type="button" onClick={() => setSheet("categories")} onPointerDown={(event) => { dragStartY.current = event.clientY; try { event.currentTarget.setPointerCapture(event.pointerId); } catch { /* Synthetic events may not own an active pointer. */ } }} onPointerUp={(event) => { finishCategoryDrag(event.clientY); if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId); }} onPointerCancel={() => { dragStartY.current = null; }}><i /><span>الأقسام</span><ChevronUp /></button>}
      </div>}

      {sheet && <div className="category-sheet-layer" role="presentation" onPointerDown={(event) => { if (event.target === event.currentTarget) setSheet(null); }}>
        <section className="category-bottom-sheet" role="dialog" aria-modal="true" aria-label={sheet === "filters" ? "فلترة المنتجات" : "باقي الأقسام"}>
          <button className="category-sheet-close" type="button" onClick={() => setSheet(null)} aria-label="إغلاق"><X /></button>
          <i className="category-sheet-grip" />
          {sheet === "filters" ? <>
            <header><div><small>خيارات سريعة</small><h2>فلترة المنتجات</h2></div>{activeFilterCount > 0 && <button type="button" onClick={resetFilters}>إعادة ضبط</button>}</header>
            {availableSizes.length > 0 && <div className="category-filter-group"><strong>المقاس</strong><div>{availableSizes.map((item) => <button className={size === item ? "selected" : ""} type="button" key={item} onClick={() => setSize(size === item ? "" : item)}>{item}{size === item && <Check />}</button>)}</div></div>}
            <div className="category-filter-group"><strong>السعر</strong><div>{([['all', 'الكل'], ['under300', 'أقل من 300'], ['300to500', '300 - 500'], ['over500', 'أكثر من 500']] as const).map(([value, label]) => <button className={price === value ? "selected" : ""} type="button" key={value} onClick={() => setPrice(value)}>{label}{price === value && <Check />}</button>)}</div></div>
            <div className="category-filter-group"><strong>الترتيب</strong><div>{([['newest', 'الأحدث'], ['priceLow', 'الأقل سعرًا'], ['priceHigh', 'الأعلى سعرًا']] as const).map(([value, label]) => <button className={sort === value ? "selected" : ""} type="button" key={value} onClick={() => setSort(value)}>{label}{sort === value && <Check />}</button>)}</div></div>
            <label className="category-stock-switch"><span><strong>المتوفر فقط</strong><small>إخفاء القطع النافدة</small></span><input type="checkbox" checked={inStockOnly} onChange={(event) => setInStockOnly(event.target.checked)} /><i /></label>
            <button className="category-apply-filter" type="button" onClick={() => setSheet(null)}>عرض {visibleProducts.length} {visibleProducts.length === 1 ? "منتج" : "منتجات"}</button>
          </> : <>
            <header><div><small>اسحبي واختاري</small><h2>أقسام كارمن كارلا</h2></div></header>
            <div className="category-sheet-list">{managedCategories.map((item) => {
              const filter = item.productCategoryFilter?.trim() || item.title;
              const current = cleanCategory(filter) === cleanCategory(requestedCategory);
              return <Link className={current ? "current" : ""} href={`/category/?name=${encodeURIComponent(filter)}&title=${encodeURIComponent(item.title)}`} key={item.id} onClick={() => setSheet(null)}>{item.imageUrl ? <img src={item.imageUrl} alt="" /> : <span>Carmen Karla</span>}<strong>{item.title}</strong>{current && <Check />}</Link>;
            })}</div>
          </>}
        </section>
      </div>}
    </main>
  );
}

export default function CategoryPage() {
  return <Suspense fallback={<div className="page-loading">جارٍ فتح القسم...</div>}><CategoryCollection /></Suspense>;
}
