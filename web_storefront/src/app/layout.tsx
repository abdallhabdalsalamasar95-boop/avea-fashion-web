import type { Metadata } from "next";
import { Cairo } from "next/font/google";
import { Header } from "@/components/header";
import { AuthProvider } from "@/components/auth-provider";
import { AmbassadorProvider } from "@/components/ambassador-context";
import { StoreProvider } from "@/components/store-provider";
import { SiteAppearanceProvider } from "@/components/site-appearance-provider";
import { SiteFooter } from "@/components/site-footer";
import { AppInstallPrompt } from "@/components/app-install-prompt";
import { PresenceBeacon } from "@/components/presence-beacon";
import { PwaRegister } from "@/components/pwa-register";
import { SocialLinks } from "@/components/social-links";
import "./globals.css";

// إضافة خط القاهرة العصري والأنيق للموقع
const cairo = Cairo({
  subsets: ["arabic"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-cairo",
});

const APP_URL = process.env.NEXT_PUBLIC_APP_URL || "https://karla.onrender.com";

export const viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0f172a",
};

export const metadata: Metadata = {
  metadataBase: new URL(APP_URL),
  applicationName: "Carmen Karla",
  title: { default: "Carmen Karla | أناقتك تبدأ هنا", template: "%s | Carmen Karla" },
  description: "متجر كارمن كارلا للأزياء النسائية العصرية في ليبيا. تسوقي أحدث الفساتين والعبايات مع الدفع عند الاستلام.",
  keywords: ["أزياء نسائية", "فساتين", "عبايات", "ليبيا", "Carmen Karla", "كارمن كارلا"],
  icons: { icon: "/icon-192.png", apple: "/apple-touch-icon.png" },
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "Carmen Karla", statusBarStyle: "default" },
  openGraph: {
    title: "Carmen Karla",
    description: "أناقتك، بطريقتك",
    locale: "ar_LY",
    type: "website",
    url: APP_URL,
    siteName: "Carmen Karla",
    images: [{ url: "/icon-512.png", width: 512, height: 512, alt: "Carmen Karla" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Carmen Karla",
    description: "أناقتك، بطريقتك",
    images: ["/icon-512.png"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ar" dir="rtl" data-scroll-behavior="smooth">
      <body className={cairo.className}>
        <AuthProvider>
          <AmbassadorProvider>
            <StoreProvider>
              <SiteAppearanceProvider>
                <PwaRegister />
                <PresenceBeacon />
                <Header />
                <main>{children}</main>
                <SocialLinks />
                <SiteFooter />
                <AppInstallPrompt />
              </SiteAppearanceProvider>
            </StoreProvider>
          </AmbassadorProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
