"use client";

import { usePathname } from "next/navigation";

export function SiteFooter() {
  const pathname = usePathname();

  if (!pathname.startsWith("/account")) {
    return null;
  }

  return (
    <footer className="footer">
      <div className="container footer-grid">
        <div><div className="brand footer-brand"><span>AVEA</span><small>FASHION</small></div><p>أزياء مختارة بعناية لتعبّر عنكِ في كل مناسبة.</p></div>
        <div><h3>تسوّقي</h3><a href="/#collection">وصل حديثًا</a><a href="/favorites/">المفضلة</a><a href="/cart/">سلة التسوق</a></div>
        <div><h3>خدمة العملاء</h3><a href="mailto:support@aveafashion.com">تواصلي معنا</a><span>الدفع عند الاستلام</span><span>توصيل لجميع مدن ليبيا</span></div>
        <div><h3>السياسات</h3><a href="/privacy/">الخصوصية</a><a href="/terms/">الشروط والأحكام</a><a href="/returns/">الاستبدال والاسترجاع</a></div>
      </div>
      <p className="copyright">© 2026 AVEA FASHION — جميع الحقوق محفوظة</p>
    </footer>
  );
}
