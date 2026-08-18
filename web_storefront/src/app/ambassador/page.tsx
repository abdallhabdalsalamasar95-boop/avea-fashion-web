"use client";

import Link from "next/link";
import { ArrowLeft, BadgeCheck, BadgePercent, Check, PackageCheck, Sparkles, WalletCards } from "lucide-react";
import { useEffect, useState } from "react";
import { AmbassadorPortal } from "@/components/ambassador-portal";
import { AmbassadorSupportButton } from "@/components/ambassador-support-button";
import { fetchAppContent } from "@/lib/api";
import { AppContent } from "@/lib/types";

export default function AmbassadorPage() {
  const [content, setContent] = useState<AppContent>({});

  useEffect(() => {
    const controller = new AbortController();
    fetchAppContent(controller.signal).then(setContent).catch(() => undefined);
    return () => controller.abort();
  }, []);

  return <main className="ambassador-page">
    <section className="ambassador-hero">
      <div className="container ambassador-hero-grid">
        <div className="ambassador-hero-copy">
          <span><Sparkles /> فرصة عمل مرنة مع AVEA FASHION</span>
          <h1>كوني مندوبة مبيعات<br />وابني دخلك بطريقتك</h1>
          <p>سوّقي منتجات أڤيا لعميلاتك واكسبي عمولتك عند نجاح التوصيل — بدون شراء مخزون أو رسوم تسجيل.</p>
          <div className="ambassador-hero-actions">
            <a className="ambassador-primary" href="#join">انضمي الآن <ArrowLeft /></a>
            <Link className="ambassador-secondary" href="/#collection">استكشفي التشكيلة</Link>
          </div>
          <div className="ambassador-trust"><span><Check /> بدون رسوم تسجيل</span><span><Check /> وقت عمل مرن</span><span><Check /> دعم مستمر</span></div>
        </div>
        <div className="ambassador-commission-card">
          <div className="commission-glow" />
          <span className="commission-icon"><BadgePercent /></span>
          <small>عمولة خاصة بكل منتج</small>
          <strong>اختاري وربحي</strong>
          <p>تظهر قيمة العمولة بوضوح على كل منتج، وتُعتمد بعد توصيل الطلب بنجاح.</p>
          <div><BadgeCheck /> لا توجد نسبة موحّدة على جميع المنتجات</div>
        </div>
      </div>
    </section>

    <section className="container ambassador-simple-benefits">
      <div><WalletCards /><span><strong>عمولة واضحة</strong><small>على كل طلب موصّل</small></span></div>
      <div><PackageCheck /><span><strong>بدون مخزون</strong><small>نجهز ونوصل عنك</small></span></div>
      <div><BadgeCheck /><span><strong>لوحة واحدة</strong><small>للطلبات والأرباح</small></span></div>
    </section>

    <section className="ambassador-quick-join">
      <div className="container">
        <div className="ambassador-section-heading"><span>ابدئي الآن</span><h2>ثلاث بيانات وتصبح لوحتك جاهزة</h2><p>أنشئي حسابًا أو سجّلي الدخول، ثم أدخلي الاسم والهاتف والمنطقة.</p></div>
        <div className="ambassador-join" id="join"><AmbassadorPortal /></div>
      </div>
    </section>
    <AmbassadorSupportButton number={content.ambassadorSupport?.whatsappNumber} enabled={content.ambassadorSupport?.enabled} />
  </main>;
}