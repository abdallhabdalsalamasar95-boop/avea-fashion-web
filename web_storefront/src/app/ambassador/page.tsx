"use client";

import Link from "next/link";
import { ArrowLeft, Check, Sparkles } from "lucide-react";
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
          <span><Sparkles /> فرصة عمل مرنة مع Carmen Karla</span>
          <h1>كن مندوب مبيعات<br />وابنِ دخلك بطريقتك</h1>
          <p>شاركي منتجات كارمن كارلا مع عميلاتك، واكسبي عمولتك عند نجاح التوصيل.</p>
          <div className="ambassador-hero-actions">
            <a className="ambassador-primary" href="#join">انضمي الآن <ArrowLeft /></a>
            <Link className="ambassador-secondary" href="/#collection">استكشفي التشكيلة</Link>
          </div>
          <div className="ambassador-trust"><span><Check /> بدون رسوم</span><span><Check /> بدون مخزون</span><span><Check /> وقت مرن</span></div>
        </div>
      </div>
    </section>

    <section className="container ambassador-simple-benefits">
      <div><b>1</b><span><strong>سجّلي بياناتك</strong><small>الاسم والهاتف والمنطقة فقط</small></span></div>
      <div><b>2</b><span><strong>شاركي المنتجات</strong><small>لكل قطعة رابط خاص باسمك</small></span></div>
      <div><b>3</b><span><strong>اكسبي عمولتك</strong><small>تُعتمد بعد توصيل الطلب بنجاح</small></span></div>
    </section>

    <section className="ambassador-quick-join">
      <div className="container">
        <div className="ambassador-section-heading"><span>ابدئي الآن</span><h2>ثلاث بيانات وتصبح لوحتك جاهزة</h2></div>
        <div className="ambassador-join" id="join"><AmbassadorPortal /></div>
      </div>
    </section>
    <AmbassadorSupportButton number={content.ambassadorSupport?.whatsappNumber} enabled={content.ambassadorSupport?.enabled} />
  </main>;
}