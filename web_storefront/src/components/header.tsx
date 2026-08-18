"use client";

import Link from "next/link";
import { BadgePercent, Heart, Home, Search, ShoppingBag, Store, UserRound } from "lucide-react";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import type { CSSProperties } from "react";
import { useStore } from "@/components/store-provider";
import { useAuth } from "@/components/auth-provider";
import { LocaleToggle } from "@/components/locale-toggle";
import { AppInstallPrompt } from "@/components/app-install-prompt";
import { fetchAppContent } from "@/lib/api";
import { AppContent } from "@/lib/types";

const links = [
  ["/", "الرئيسية"],
  ["/#collection", "المتجر"],
  ["/favorites/", "المفضلة"],
  ["/ambassador/", "مندوبة مبيعات"],
  ["/account/", "حسابي وطلباتي"],
  ["/#about", "عن كارمن كارلا"],
];

export function Header() {
  const { cartCount, favorites } = useStore();
  const { user } = useAuth();
  const [announcement, setAnnouncement] = useState<NonNullable<NonNullable<AppContent["websiteHome"]>["announcement"]>>({
    text: "شحن لجميع المدن الليبية • الدفع عند الاستلام",
    enabled: true,
    speedSeconds: 18,
    style: "rose",
  });
  const pathname = usePathname();

  useEffect(() => {
    fetchAppContent()
      .then((content) => {
        if (content.websiteHome?.announcement) setAnnouncement(content.websiteHome.announcement);
      })
      .catch(() => {});
  }, []);

  const announcementText = announcement.text?.trim();
  const announcementSpeed = Math.max(6, Math.min(60, announcement.speedSeconds ?? 18));

  return (
    <><header className="site-header">
      {announcement.enabled !== false && announcementText && <div className={`announcement announcement--${announcement.style ?? "rose"}`} aria-label={announcementText}>
        <div className="announcement-track" style={{ "--announcement-duration": `${announcementSpeed}s` } as CSSProperties} aria-hidden="true">
          <span>{announcementText}<i>•</i>{announcementText}</span>
          <span>{announcementText}<i>•</i>{announcementText}</span>
        </div>
      </div>}
      <div className="nav-shell container">
        <AppInstallPrompt />
        <Link className="brand" href="/" aria-label="كارمن كارلا الرئيسية">
          <span>CK</span>
          <small>KARLA</small>
        </Link>
        <nav className="nav-links">
          {links.map(([href, label]) => <Link key={href} href={href}>{label}</Link>)}
        </nav>
        <div className="nav-actions">
          <LocaleToggle />
          <a className="icon-button" href="/#collection" aria-label="البحث"><Search /></a>
          <Link className="icon-button desktop-only count-anchor" href="/favorites/" aria-label="المفضلة">
            <Heart />{favorites.length > 0 && <b>{favorites.length}</b>}
          </Link>
          <Link className={user ? "icon-button signed" : "icon-button"} href="/account/" aria-label="الحساب"><UserRound /></Link>
          <Link className="icon-button count-anchor" href="/cart/" aria-label="سلة التسوق" data-cart-target="desktop">
            <ShoppingBag />{cartCount > 0 && <b>{cartCount}</b>}
          </Link>
        </div>
      </div>
    </header>
    <nav className="mobile-bottom-nav" aria-label="التنقل السريع">
      <Link className={pathname === "/" ? "active" : ""} href="/"><Home /><span>الرئيسية</span></Link>
      <Link href="/#collection"><Store /><span>المتجر</span></Link>
      <Link className={pathname.startsWith("/ambassador") ? "active" : ""} href="/ambassador/"><BadgePercent /><span>المندوبات</span></Link>
      <Link className={pathname.startsWith("/cart") || pathname.startsWith("/checkout") ? "active count-anchor" : "count-anchor"} href="/cart/" data-cart-target="mobile"><ShoppingBag />{cartCount > 0 && <b>{cartCount}</b>}<span>السلة</span></Link>
      <Link className={pathname.startsWith("/account") ? "active" : ""} href="/account/"><UserRound /><span>حسابي</span></Link>
    </nav></>
  );
}
