"use client";

import Link from "next/link";
import {
  ArrowLeft,
  ChevronDown,
  Heart,
  Search,
  ShieldCheck,
  ShoppingBag,
  Sparkles,
  Star,
  Truck,
} from "lucide-react";

const products = [
  { id: 1, name: "آلتي فستان", tag: "Evening Luxe", price: "490 ر.س", oldPrice: "620 ر.س", badge: "SALE", rating: 4.9 },
  { id: 2, name: "غلاف فاخر", tag: "Signature Piece", price: "380 ر.س", oldPrice: "500 ر.س", badge: "NEW", rating: 4.8 },
  { id: 3, name: "بدلة أنيقة", tag: "Premium Edit", price: "720 ر.س", oldPrice: "860 ر.س", badge: "EXCLUSIVE", rating: 5.0 },
  { id: 4, name: "فستان يومي", tag: "Day to Night", price: "420 ر.س", oldPrice: "560 ر.س", badge: "TOP", rating: 4.7 },
];

const categories = [
  { title: "فساتين", accent: "Occasion" },
  { title: "أزياء", accent: "Modern" },
  { title: "إكسسوارات", accent: "Luxury" },
  { title: "ملابس", accent: "Essentials" },
];

export default function AVEAPremiumHomepage() {
  return (
    <>
      <div className="page-shell">
        <div className="announcement">توصيل سريع لجميع المدن • خصومات حصرية على تشكيلة الموسم</div>

        <header className="site-header">
          <div className="container nav-shell">
            <div className="brand">
              <span>AVEA</span>
              <small>FASHION</small>
            </div>

            <nav className="nav-links" aria-label="الرئيسية">
              <Link href="#">الرئيسية</Link>
              <Link href="#collection">التشكيلة</Link>
              <Link href="#new">وصل حديثًا</Link>
              <Link href="#editorial">قصتنا</Link>
              <Link href="#contact">تواصل</Link>
            </nav>

            <div className="nav-actions">
              <button className="icon-button" aria-label="بحث">
                <Search />
              </button>
              <button className="icon-button count-anchor" aria-label="المفضلة">
                <Heart />
                <b>2</b>
              </button>
              <button className="icon-button count-anchor" aria-label="السلة">
                <ShoppingBag />
                <b>4</b>
              </button>
            </div>
          </div>
        </header>

        <main>
          <section className="hero">
            <div className="hero-cover">
              <img
                src="https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80"
                alt="Model"
              />
            </div>

            <div className="container hero-content">
              <span>Curated for your elegance</span>
              <h1>تشكيلة أنيقة تجمع بين الفخامة والراحة.</h1>
              <Link href="#collection" className="hero-button">
                تسوق الآن <ArrowLeft />
              </Link>
            </div>

            <div className="hero-scroll">
              <i /> SCROLL
            </div>
          </section>

          <aside className="offer-strip">
            <Sparkles />
            <span>خصم 10% على أول طلب • شحن سريع داخل المدن الكبرى</span>
          </aside>

          <section className="shop-the-look container" aria-label="تسوق حسب أسلوبك">
            <div className="shop-the-look-header">
              <div>
                <span>style stories</span>
                <h2>تسوقي حسب أسلوبك</h2>
              </div>
              <Link href="#collection">اكتشفي الكل <ArrowLeft /></Link>
            </div>

            <div className="look-grid">
              <article className="look-card look-card-dark">
                <div className="look-copy">
                  <span>Occasion Edit</span>
                  <h3>إطلالات الاحتفال</h3>
                  <p>فساتين أنيقة وقطع فاخرة تناسب soirées، حفلات، ومناسباتك الخاصة.</p>
                </div>
              </article>

              <article className="look-card look-card-light">
                <div className="look-copy">
                  <span>Essential Wardrobe</span>
                  <h3>قطع يومية أنيقة</h3>
                  <p>أزياء مريحة، مميزة، ومناسبة للاستخدام اليومي مع لمسة فاخرة.</p>
                </div>
              </article>

              <article className="look-card look-card-gold">
                <div className="look-copy">
                  <span>Premium Picks</span>
                  <h3>اختيارات فاخرة</h3>
                  <p>قطع مختارة بعناية لتمنحك حضورًا أنيقًا في كل قرار لباسك.</p>
                </div>
              </article>
            </div>
          </section>

          <section className="luxury-edit container" aria-label="تحرير مختار">
            <div className="luxury-header">
              <div>
                <span>curated edit</span>
                <h2>اختياراتك المميزة لهذا الموسم</h2>
              </div>
              <Link href="#collection">تصفّحي كل المجموعات <ArrowLeft /></Link>
            </div>

            <div className="luxury-grid">
              <article className="luxury-card luxury-card-featured">
                <div className="card-copy">
                  <span>Evening Luxe</span>
                  <h3>إطلالات أنيقة للليل</h3>
                  <p>فساتين أنيقة وبدلات عصرية مصممة لإبهار كل مناسبة احتفالية.</p>
                  <Link href="#collection">تسوق الآن <ArrowLeft /></Link>
                </div>
              </article>

              <article className="luxury-card luxury-card-soft">
                <span>Day to Night</span>
                <h3>ستايل متوازن</h3>
                <p>تشكيلات سهلة ومريحة تناسب المكتب والرحلات والارتداء اليومي.</p>
              </article>

              <article className="luxury-card luxury-card-contrast">
                <span>Signature Pieces</span>
                <h3>قطع مميزة</h3>
                <p>أقمشة راقية، تفاصيل أنيقة، وموديلات تنافس أبرز المتاجر العالمية.</p>
              </article>
            </div>
          </section>

          <section className="category-showcase container" id="new">
            <div className="section-kicker">
              <h2>اكتشفي أقسامنا</h2>
              <Link href="#collection">تصفّحي الكل <ArrowLeft /></Link>
            </div>

            <div className="category-cards">
              {categories.map((item) => (
                <Link href="#collection" className="category-link" key={item.title}>
                  <img
                    src={`https://images.unsplash.com/photo-${["1529139574466-a303027c1d8b", "1524504388940-b1c1722653e1", "1496747611176-843222e1e57c", "1521572267360-ee0c2909d518"][Math.floor(Math.random() * 4)]}?auto=format&fit=crop&w=900&q=80`}
                    alt={item.title}
                  />
                  <span>
                    <small>{item.accent}</small>
                    <strong>{item.title}</strong>
                    <em>تسوقي الآن <ArrowLeft /></em>
                  </span>
                </Link>
              ))}
            </div>
          </section>

          <section className="home-product-section container" aria-labelledby="newest-title">
            <div className="home-rail-heading">
              <div>
                <span>وصل حديثًا</span>
                <h2 id="newest-title">الأحدث</h2>
                <p>أجدد الموديلات المختارة بعناية لأسلوبك اليوم.</p>
              </div>
              <small>اسحبي لليسار <ArrowLeft /></small>
            </div>

            <div className="home-product-rail">
              {products.map((product) => (
                <article key={product.id} className="product-card">
                  <div className="product-media">
                    <button className="favorite-button" aria-label="إضافة للمفضلة">
                      <Heart />
                    </button>
                    <span className="sale-badge">{product.badge}</span>
                    <img
                      src="https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80"
                      alt={product.name}
                    />
                    <button className="quick-add">
                      <ShoppingBag />
                      أضف إلى السلة
                    </button>
                  </div>

                  <div className="product-info">
                    <div className="product-meta">
                      <span>{product.tag}</span>
                      <span className="rating">
                        <Star />
                        {product.rating}
                      </span>
                    </div>
                    <h3>{product.name}</h3>
                    <div className="price">
                      <strong>{product.price}</strong>
                      <del>{product.oldPrice}</del>
                    </div>
                    <span className="commission">خصم خاص</span>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section className="collection container" id="collection">
            <div className="section-heading">
              <div>
                <h2>كل المنتجات</h2>
              </div>
              <a href="#" className="view-all">تصفّحي الكل <ArrowLeft /></a>
            </div>

            <div className="catalog-controls">
              <label className="search-box">
                <Search />
                <input type="text" placeholder="ابحثي عن منتج..." />
              </label>
            </div>

            <div className="category-list">
              <button className="active">الكل</button>
              <button>فساتين</button>
              <button>ملابس</button>
              <button>إكسسوارات</button>
              <button>ملابس داخلية</button>
            </div>

            <div className="catalog-toolbar">
              <p>
                <strong>40</strong> منتج
              </p>
              <div>
                <label className="stock-toggle">
                  <input type="checkbox" />
                  <span />
                  المتوفر فقط
                </label>
                <label className="sort-select">
                  <span>ترتيب حسب</span>
                  <select defaultValue="featured">
                    <option value="featured">المقترحة</option>
                    <option value="newest">الأحدث</option>
                    <option value="price-low">السعر: الأقل أولًا</option>
                    <option value="price-high">السعر: الأعلى أولًا</option>
                  </select>
                  <ChevronDown />
                </label>
              </div>
            </div>

            <div className="product-grid">
              {products.map((product) => (
                <article key={product.id + "grid"} className="product-card">
                  <div className="product-media">
                    <button className="favorite-button" aria-label="إضافة للمفضلة">
                      <Heart />
                    </button>
                    <span className="sale-badge">{product.badge}</span>
                    <img
                      src="https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80"
                      alt={product.name}
                    />
                    <button className="quick-add">
                      <ShoppingBag />
                      أضف إلى السلة
                    </button>
                  </div>

                  <div className="product-info">
                    <div className="product-meta">
                      <span>{product.tag}</span>
                      <span className="rating">
                        <Star />
                        {product.rating}
                      </span>
                    </div>
                    <h3>{product.name}</h3>
                    <div className="price">
                      <strong>{product.price}</strong>
                      <del>{product.oldPrice}</del>
                    </div>
                    <span className="commission">خصم خاص</span>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section className="editorial" id="editorial">
            <div className="container editorial-grid">
              <div className="editorial-copy">
                <span>عن AVEA</span>
                <h2>أسلوب فاخر يناسب كل لحظة في حياتك</h2>
                <p>
                  نختار لك تشكيلة من الفساتين، العبايات، والأزياء الأنيقة بعناية لتجمع بين الراحة، الفخامة، والهوية الشخصية. كل قطعة من تصميمنا يُصنع ليمنحك إطلالة متوازنة ومميزة في كل مناسبة.
                </p>
                <Link href="#collection">اكتشفي التشكيلة <ArrowLeft /></Link>
              </div>

              <div className="editorial-stats" aria-label="إحصاءات المتجر">
                <div>
                  <strong>+18k</strong>
                  <span>عميلة راضية</span>
                </div>
                <div>
                  <strong>2.5k</strong>
                  <span>منتج جديد</span>
                </div>
                <div>
                  <strong>24/7</strong>
                  <span>دعم متواصل</span>
                </div>
              </div>
            </div>
          </section>

          <section className="luxury-cta container" aria-label="عرض فاخر">
            <div className="luxury-cta-panel">
              <div className="luxury-cta-copy">
                <span>limited collection</span>
                <h2>مجموعة مختارة لملامحك المميزة</h2>
                <p>فساتين وبدلات أنيقة تم اختيارها بعناية لتليق بكل مناسبة، من المكتب إلى الأمسيات الفاخرة.</p>
                <Link href="#collection">تسوقي الآن <ArrowLeft /></Link>
              </div>

              <div className="luxury-cta-badges" aria-label="مزايا المتجر">
                <span>توصيل سريع</span>
                <span>دفع آمن</span>
                <span>خدمة مميزة</span>
              </div>
            </div>
          </section>

          <section className="benefits container" id="contact">
            <div>
              <Truck />
              <span>
                <strong>توصيل لكل ليبيا</strong>
                <small>بسرعة وأمان</small>
              </span>
            </div>
            <div>
              <ShieldCheck />
              <span>
                <strong>تسوّق آمن</strong>
                <small>الدفع عند الاستلام</small>
              </span>
            </div>
            <div>
              <Sparkles />
              <span>
                <strong>اختيارات مميزة</strong>
                <small>تشكيلات متجددة</small>
              </span>
            </div>
          </section>
        </main>
      </div>

      <style jsx>{`
        :root {
          --rose:#b25078;
          --rose-dark:#713047;
          --rose-light:#f5e4e9;
          --gold:#c7a96a;
          --ink:#211a1d;
          --muted:#75696e;
          --cream:#fbf8f5;
          --white:#fff;
          --line:#e9e0e2;
          --shadow:0 24px 60px rgba(52,31,39,.11);
          --font-arabic:Tahoma,"Segoe UI",Arial,sans-serif;
        }
        * { box-sizing:border-box; }
        html { scroll-behavior:smooth; }
        body { margin:0; background:var(--cream); color:var(--ink); font-family:var(--font-arabic); }
        a { color:inherit; text-decoration:none; }
        button,input,select,textarea { font:inherit; }
        button { cursor:pointer; }
        .container { width:min(1240px,calc(100% - 40px)); margin-inline:auto; }
        .announcement { background:#211a1d; color:#fff; text-align:center; font-size:12px; letter-spacing:.2px; padding:8px; }
        .site-header { position:sticky; top:0; z-index:50; backdrop-filter:blur(16px); background:rgba(253,248,244,.93); border-bottom:1px solid rgba(178,80,120,.09); }
        .nav-shell { height:82px; display:flex; align-items:center; gap:36px; }
        .brand { display:flex; flex-direction:column; align-items:center; line-height:.8; min-width:88px; }
        .brand span { font-family:Georgia,serif; font-size:27px; letter-spacing:5px; color:var(--rose-dark); }
        .brand small { font-size:8px; letter-spacing:4px; color:var(--gold); margin-top:9px; }
        .nav-links { display:flex; gap:30px; flex:1; justify-content:center; font-size:14px; }
        .nav-links a { position:relative; padding:8px 2px; }
        .nav-links a:after { content:""; position:absolute; right:0; bottom:0; width:0; height:2px; background:var(--rose); transition:.25s; }
        .nav-links a:hover:after { width:100%; }
        .nav-actions { display:flex; align-items:center; gap:7px; }
        .icon-button { width:40px; height:40px; border:0; background:transparent; border-radius:50%; display:grid; place-items:center; transition:.2s; position:relative; }
        .icon-button:hover { background:var(--rose-light); color:var(--rose-dark); }
        .icon-button svg { width:20px; }
        .count-anchor b { position:absolute; top:0; left:0; min-width:17px; height:17px; border-radius:20px; background:var(--rose); color:#fff; font-size:10px; display:grid; place-items:center; padding:0 4px; }
        .hero { height:min(720px,calc(100svh - 112px)); min-height:570px; overflow:hidden; position:relative; display:flex; align-items:center; background:#f2eeeb; }
        .hero-cover { position:absolute; inset-block:0; inset-inline-end:0; width:58%; overflow:hidden; background:#ded7d4; }
        .hero-cover img { width:100%; height:100%; object-fit:cover; object-position:center 18%; display:block; }
        .hero-content { position:relative; z-index:2; }
        .hero-content>span { display:block; color:#9a7a67; font:11px Georgia,serif; letter-spacing:5px; margin-bottom:18px; }
        .hero h1 { max-width:40%; font:400 clamp(56px,6.4vw,92px)/1.05 Georgia,"Times New Roman",serif; letter-spacing:-2px; margin:0 0 35px; color:#211a1d; }
        .hero-button { display:inline-flex; align-items:center; justify-content:center; gap:28px; min-width:180px; padding:15px 22px; background:#211a1d; color:#fff; font-size:13px; transition:.25s; }
        .hero-button:hover { background:var(--rose-dark); transform:translateY(-2px); }
        .hero-button svg { width:16px; }
        .hero-scroll { position:absolute; z-index:3; bottom:26px; right:calc(21% - 20px); display:flex; align-items:center; gap:10px; color:#756c6f; font-size:9px; letter-spacing:1px; transform:rotate(-90deg); transform-origin:right center; }
        .hero-scroll i { display:block; width:50px; height:1px; background:#968c8f; }
        .offer-strip { display:flex; align-items:center; justify-content:center; gap:10px; padding:13px 20px; background:var(--rose-dark); color:#fff; font-size:14px; }
        .offer-strip svg { width:18px; color:#e9cc8e; }
        .shop-the-look { padding-top:30px; }
        .shop-the-look-header { display:flex; align-items:end; justify-content:space-between; gap:20px; margin-bottom:22px; }
        .shop-the-look-header span { display:block; margin-bottom:8px; color:var(--rose-dark); font-size:10px; font-weight:800; letter-spacing:1px; text-transform:uppercase; }
        .shop-the-look-header h2 { margin:0; font-family:Georgia,"Times New Roman",serif; font-size:clamp(28px,4vw,42px); font-weight:400; line-height:1.15; }
        .shop-the-look-header a { display:inline-flex; align-items:center; gap:8px; color:var(--ink); font-size:12px; font-weight:700; padding-bottom:4px; border-bottom:1px solid rgba(33,26,29,.35); }
        .shop-the-look-header a svg { width:15px; }
        .look-grid { display:grid; grid-template-columns:1.2fr 1fr 1fr; gap:18px; }
        .look-card { position:relative; min-height:320px; border-radius:26px; overflow:hidden; padding:28px; display:flex; align-items:flex-end; border:1px solid rgba(33,26,29,.08); box-shadow:0 18px 50px rgba(44,31,36,.06); }
        .look-card::before { content:""; position:absolute; inset:0; background:linear-gradient(180deg,rgba(255,255,255,.06),rgba(22,16,18,.44)); }
        .look-card-dark { background:linear-gradient(135deg,#2f2528,#5b4743 45%,#a67e68); }
        .look-card-light { background:linear-gradient(135deg,#f4ece8,#e2d4c9 50%,#ddb59d); }
        .look-card-gold { background:linear-gradient(135deg,#c8a76a,#8c6d3f 52%,#4b392b); }
        .look-copy { position:relative; z-index:1; }
        .look-copy span { display:inline-block; margin-bottom:12px; padding:7px 10px; border-radius:999px; background:rgba(255,255,255,.15); color:#fff; font-size:9px; letter-spacing:1px; text-transform:uppercase; font-weight:800; }
        .look-card-light .look-copy span { background:rgba(33,26,29,.08); color:#402d2d; }
        .look-copy h3 { margin:0 0 10px; font-family:Georgia,"Times New Roman",serif; font-size:clamp(22px,2vw,30px); line-height:1.2; color:#fff; }
        .look-card-light .look-copy h3 { color:#2a1d20; }
        .look-copy p { margin:0; max-width:28ch; color:rgba(255,255,255,.9); line-height:1.8; font-size:14px; }
        .look-card-light .look-copy p { color:rgba(42,29,32,.8); }
        .luxury-edit { padding-block:42px 6px; }
        .luxury-header { display:flex; align-items:end; justify-content:space-between; gap:20px; margin-bottom:20px; }
        .luxury-header span, .editorial-copy span { display:block; margin-bottom:8px; color:var(--rose-dark); font-size:10px; font-weight:800; letter-spacing:1px; text-transform:uppercase; }
        .luxury-header h2, .editorial-copy h2 { margin:0; font-family:Georgia,"Times New Roman",serif; font-size:clamp(28px,4vw,42px); font-weight:400; line-height:1.15; }
        .luxury-header a, .editorial-copy a, .section-kicker a { display:inline-flex; align-items:center; gap:8px; color:var(--ink); font-size:12px; font-weight:700; padding-bottom:4px; border-bottom:1px solid rgba(33,26,29,.35); }
        .luxury-grid { display:grid; grid-template-columns:1.4fr 0.9fr 0.9fr; gap:18px; }
        .luxury-card { position:relative; min-height:300px; border-radius:24px; padding:26px; overflow:hidden; border:1px solid rgba(113,48,71,.08); box-shadow:0 24px 60px rgba(52,31,39,.06); }
        .luxury-card::before { content:""; position:absolute; inset:0; background:linear-gradient(135deg,rgba(255,255,255,.1),transparent 50%,rgba(23,16,19,.12)); }
        .luxury-card-featured { background:linear-gradient(135deg,#f1e7df,#ead3c8 42%,#d4b8a3 100%); }
        .luxury-card-soft { background:linear-gradient(135deg,#f8f1f1,#f2e3e7); }
        .luxury-card-contrast { background:linear-gradient(135deg,#201a1d,#3b2a2e 58%,#8a615f); color:#fff; }
        .luxury-card > * { position:relative; z-index:1; }
        .luxury-card span { display:inline-block; padding:6px 10px; border-radius:999px; background:rgba(255,255,255,.42); font-size:10px; letter-spacing:.8px; text-transform:uppercase; font-weight:800; }
        .luxury-card h3 { margin:18px 0 12px; font-size:clamp(22px,2vw,30px); font-family:Georgia,"Times New Roman",serif; line-height:1.2; }
        .luxury-card p { margin:0; max-width:28ch; color:rgba(33,26,29,.82); line-height:1.8; font-size:14px; }
        .luxury-card-contrast p, .luxury-card-contrast span { color:#f8eee8; }
        .luxury-card-contrast span { background:rgba(255,255,255,.08); }
        .luxury-card-featured .card-copy { display:flex; flex-direction:column; justify-content:flex-end; height:100%; }
        .luxury-card-featured .card-copy a { margin-top:18px; color:var(--ink); }
        .category-showcase { padding-block:80px 25px; }
        .section-kicker { display:flex; align-items:end; justify-content:space-between; margin-bottom:27px; }
        .section-kicker h2 { font:38px Georgia,serif; font-weight:400; margin:0; }
        .category-cards { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; }
        .category-link { position:relative; display:block; height:390px; overflow:hidden; border-radius:22px; }
        .category-link img { width:100%; height:100%; object-fit:cover; transition:transform .7s ease; }
        .category-link:hover img { transform:scale(1.05); }
        .category-link:after { content:""; position:absolute; inset:0; background:linear-gradient(0deg,rgba(23,16,19,.62),transparent 52%); }
        .category-link span { position:absolute; z-index:2; right:22px; left:22px; bottom:22px; color:#fff; display:flex; flex-direction:column; align-items:flex-start; }
        .category-link small { color:#e4d5d5; margin-bottom:5px; }
        .category-link strong { font:24px Georgia,serif; }
        .category-link em { font-style:normal; font-size:11px; display:flex; align-items:center; gap:5px; }
        .category-link em svg { width:14px; }
        .home-product-section { padding-block:58px 62px; overflow:hidden; }
        .home-product-section + .home-product-section { border-top:1px solid #eee9e6; }
        .home-rail-heading { display:flex; align-items:end; justify-content:space-between; gap:28px; margin-bottom:25px; }
        .home-rail-heading>div { min-width:0; }
        .home-rail-heading span { display:block; margin-bottom:7px; color:var(--rose-dark); font-size:10px; font-weight:800; letter-spacing:.7px; }
        .home-rail-heading h2 { margin:0; font:700 clamp(25px,3vw,35px)/1.25 "Segoe UI",sans-serif; color:#1d191b; }
        .home-rail-heading p { margin:7px 0 0; color:var(--muted); font-size:12px; }
        .home-rail-heading small { flex:0 0 auto; display:flex; align-items:center; gap:7px; color:#8d8286; font-size:10px; }
        .home-rail-heading small svg { width:15px; height:15px; }
        .home-product-rail { display:grid; grid-auto-flow:column; grid-auto-columns:calc((100% - 60px)/4); gap:20px; overflow-x:auto; overscroll-behavior-inline:contain; scroll-snap-type:inline mandatory; scrollbar-width:thin; scrollbar-color:#cbbfc3 transparent; padding:2px 1px 20px; }
        .home-product-rail>.product-card { scroll-snap-align:start; min-width:0; }
        .home-product-rail::-webkit-scrollbar { height:5px; }
        .home-product-rail::-webkit-scrollbar-track { background:#f2efed; border-radius:20px; }
        .home-product-rail::-webkit-scrollbar-thumb { background:#c6b8bd; border-radius:20px; }
        .home-product-rail .product-media { border-radius:12px; }
        .home-product-rail .product-info { padding-inline:5px; }
        .home-product-rail .quick-add { border-radius:7px; }
        .product-card { min-width:0; position:relative; }
        .product-media { aspect-ratio:3/4; position:relative; overflow:hidden; background:#f0e8e8; }
        .product-media img { display:block; width:100%; height:100%; object-fit:cover; transition:transform .6s ease; }
        .product-card:hover .product-media img { transform:scale(1.045); }
        .sale-badge { position:absolute; top:13px; right:13px; background:var(--rose-dark); color:#fff; font-size:11px; padding:6px 9px; font-weight:800; }
        .favorite-button { position:absolute; top:12px; left:12px; width:37px; height:37px; display:grid; place-items:center; border:0; border-radius:50%; background:rgba(255,255,255,.9); color:var(--ink); }
        .favorite-button svg { width:18px; }
        .quick-add { position:absolute; right:12px; left:12px; bottom:12px; border:0; background:rgba(32,24,28,.92); color:#fff; display:flex; justify-content:center; align-items:center; gap:8px; padding:11px; opacity:0; transform:translateY(10px); transition:.3s; }
        .quick-add svg { width:17px; }
        .product-card:hover .quick-add { opacity:1; transform:none; }
        .product-info { padding:15px 3px; }
        .product-meta { display:flex; align-items:center; justify-content:space-between; gap:8px; }
        .product-meta>span:first-child { font-size:10px; color:var(--rose); letter-spacing:.3px; }
        .rating { display:flex; align-items:center; gap:3px; color:#b68a31; font-size:11px; }
        .rating svg { width:12px; height:12px; }
        .product-info h3 { font:17px Georgia,serif; margin:7px 0 10px; font-weight:400; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
        .price { display:flex; align-items:center; gap:9px; }
        .price strong { color:var(--rose-dark); font-size:15px; }
        .price del { color:#a89ca1; font-size:12px; }
        .commission { display:inline-block; color:#846c35; background:#faf2dc; margin-top:8px; padding:3px 7px; border-radius:3px; }
        .collection { padding-block:75px 105px; }
        .section-heading { display:flex; justify-content:space-between; align-items:end; gap:20px; margin-bottom:28px; }
        .section-heading h2 { font-family:Georgia,"Times New Roman",serif; font-size:clamp(30px,4vw,46px); font-weight:400; margin:8px 0 0; }
        .view-all { display:inline-flex; align-items:center; gap:8px; color:var(--ink); font-size:12px; font-weight:700; padding-bottom:4px; border-bottom:1px solid rgba(33,26,29,.35); }
        .catalog-controls { padding:12px; margin-bottom:16px; border:1px solid #eee9e6; border-radius:12px; background:#fbfaf9; }
        .search-box { display:flex; align-items:center; background:#fff; border:1px solid var(--line); border-radius:30px; padding:0 17px; min-width:280px; width:min(100%,430px); box-shadow:0 5px 18px rgba(44,31,36,.04); }
        .search-box:focus-within { border-color:var(--rose); box-shadow:0 0 0 3px rgba(178,80,120,.08); }
        .search-box svg { width:18px; color:var(--muted); }
        .search-box input { width:100%; border:0; outline:0; background:transparent; padding:12px; }
        .category-list { display:flex; gap:9px; overflow:auto; scrollbar-width:none; padding-bottom:24px; }
        .category-list button { white-space:nowrap; border:1px solid var(--line); color:var(--muted); background:#fff; padding:9px 20px; border-radius:30px; }
        .category-list button.active, .category-list button:hover { color:#fff; background:var(--rose-dark); border-color:var(--rose-dark); }
        .catalog-toolbar { display:flex; align-items:center; justify-content:space-between; border-top:1px solid var(--line); padding:17px 0 24px; }
        .catalog-toolbar p { margin:0; color:var(--muted); font-size:12px; }
        .catalog-toolbar p strong { color:var(--ink); font-size:15px; }
        .catalog-toolbar>div { display:flex; align-items:center; gap:23px; }
        .stock-toggle { display:flex; align-items:center; gap:8px; color:var(--muted); font-size:12px; cursor:pointer; }
        .stock-toggle input { position:absolute; opacity:0; }
        .stock-toggle>span { width:35px; height:19px; border-radius:20px; background:#d9d0d3; position:relative; transition:.2s; }
        .stock-toggle>span:after { content:""; width:13px; height:13px; background:#fff; border-radius:50%; position:absolute; top:3px; right:3px; transition:.2s; }
        .stock-toggle input:checked+span { background:var(--rose-dark); }
        .stock-toggle input:checked+span:after { right:19px; }
        .sort-select { height:39px; border:1px solid var(--line); background:#fff; display:flex; align-items:center; padding:0 12px; gap:7px; color:var(--muted); font-size:11px; }
        .sort-select select { appearance:none; border:0; outline:0; background:transparent; color:var(--ink); padding:0 4px; cursor:pointer; }
        .sort-select svg { width:14px; }
        .product-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:38px 20px; }
        .editorial { padding:95px 0; background:#efe4df; }
        .editorial-grid { display:grid; grid-template-columns:1.15fr .85fr; align-items:center; gap:90px; }
        .editorial-copy p { max-width:610px; color:var(--muted); line-height:2; margin:18px 0 22px; }
        .editorial-stats { display:grid; grid-template-columns:repeat(3,1fr); border:1px solid rgba(113,48,71,.12); background:rgba(255,255,255,.35); border-radius:18px; overflow:hidden; }
        .editorial-stats div { text-align:center; padding:30px 14px; border-left:1px solid rgba(113,48,71,.12); }
        .editorial-stats div:first-child { border-left:0; }
        .editorial-stats strong { display:block; color:var(--rose-dark); font:26px Georgia,"Times New Roman",serif; margin-bottom:10px; }
        .editorial-stats span { color:var(--muted); font-size:11px; }
        .luxury-cta { padding-top:26px; padding-bottom:8px; }
        .luxury-cta-panel { display:grid; grid-template-columns:1.2fr .8fr; gap:20px; align-items:center; background:linear-gradient(135deg,#261d20 0%,#3a2b31 40%,#866a55 100%); border-radius:30px; padding:34px 34px; box-shadow:0 26px 60px rgba(35,22,26,.12); }
        .luxury-cta-copy span { display:block; margin-bottom:8px; color:#eac6ab; font-size:10px; font-weight:800; letter-spacing:1.2px; text-transform:uppercase; }
        .luxury-cta-copy h2 { margin:0; font-family:Georgia,"Times New Roman",serif; font-size:clamp(30px,3vw,46px); line-height:1.1; color:#fff; font-weight:400; }
        .luxury-cta-copy p { margin:16px 0 18px; color:rgba(255,255,255,.8); max-width:500px; line-height:1.9; }
        .luxury-cta-copy a { display:inline-flex; align-items:center; gap:8px; color:#fff; border-bottom:1px solid rgba(255,255,255,.45); padding-bottom:5px; font-size:12px; font-weight:700; }
        .luxury-cta-copy a svg { width:15px; }
        .luxury-cta-badges { display:flex; flex-wrap:wrap; justify-content:center; gap:12px; }
        .luxury-cta-badges span { display:inline-flex; align-items:center; justify-content:center; min-height:44px; padding:0 18px; border-radius:999px; background:rgba(255,255,255,.08); border:1px solid rgba(255,255,255,.12); color:#f9efe7; font-size:11px; font-weight:700; letter-spacing:.5px; }
        .benefits { display:grid; grid-template-columns:repeat(3,1fr); background:#fff; position:relative; z-index:3; padding:24px 34px; border-bottom:1px solid var(--line); }
        .benefits>div { display:flex; align-items:center; justify-content:center; gap:15px; border-left:1px solid var(--line); }
        .benefits>div:last-child { border-left:0; }
        .benefits svg { color:var(--rose); width:28px; }
        .benefits span { display:flex; flex-direction:column; gap:4px; }
        .benefits strong { font-size:14px; }
        .benefits small { color:var(--muted); }

        @media (max-width: 850px) {
          .home-product-rail { grid-auto-columns:calc((100% - 30px)/2.35); gap:13px; }
          .look-grid { grid-template-columns:1fr; }
          .luxury-grid { grid-template-columns:1fr; }
          .product-grid { grid-template-columns:repeat(2,1fr); }
          .category-cards { grid-template-columns:repeat(2,1fr); }
          .editorial-grid { grid-template-columns:1fr; gap:28px; }
          .luxury-cta-panel { grid-template-columns:1fr; }
          .benefits { grid-template-columns:1fr; }
          .benefits>div { border-left:0; border-top:1px solid var(--line); padding-top:18px; }
          .benefits>div:first-child { border-top:0; padding-top:0; }
        }

        @media (max-width: 560px) {
          .nav-shell { gap:10px; }
          .nav-links { gap:10px; font-size:11px; }
          .hero { min-height:500px; }
          .hero-cover { width:100%; }
          .hero h1 { max-width:70%; font-size:52px; }
          .shop-the-look-header, .luxury-header, .section-kicker, .catalog-toolbar, .section-heading { flex-direction:column; align-items:flex-start; }
          .product-grid { grid-template-columns:1fr; }
          .category-cards { grid-template-columns:1fr; }
          .home-product-rail { grid-auto-columns:calc(76%); }
          .search-box { width:100%; }
          .luxury-cta-panel { padding:20px; }
        }
      `}</style>
    </>
  );
}
