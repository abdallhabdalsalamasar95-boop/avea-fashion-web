import type { Metadata } from "next";
import { Cairo } from "next/font/google";
import { Header } from "@/components/header";
import { AuthProvider } from "@/components/auth-provider";
import { AmbassadorProvider } from "@/components/ambassador-context";
import { StoreProvider } from "@/components/store-provider";
import { SiteAppearanceProvider } from "@/components/site-appearance-provider";
import { SiteFooter } from "@/components/site-footer";
import { AppInstallPrompt } from "@/components/app-install-prompt";
import { PwaRegister } from "@/components/pwa-register";
import { SocialLinks } from "@/components/social-links";
import "./globals.css";

// إضافة خط القاهرة العصري والأنيق للموقع
const cairo = Cairo({
  subsets: ["arabic"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-cairo",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://aveafashion.com"),
  applicationName: "AVEA Fashion",
  title: { default: "AVEA Fashion | أناقتك تبدأ هنا", template: "%s | AVEA Fashion" },
  description: "متجر أڤيا فاشن للأزياء النسائية العصرية في ليبيا. تسوقي أحدث الفساتين والعبايات مع الدفع عند الاستلام.",
  keywords: ["أزياء نسائية", "فساتين", "عبايات", "ليبيا", "AVEA Fashion"],
  icons: { icon: "/icon-192.png", apple: "/apple-touch-icon.png" },
  manifest: "/manifest.webmanifest",
  themeColor: "#0f172a",
  viewport: "width=device-width, initial-scale=1, viewport-fit=cover",
  appleWebApp: { capable: true, title: "AVEA Fashion", statusBarStyle: "default" },
  openGraph: { title: "AVEA Fashion", description: "أناقتك، بطريقتك", locale: "ar_LY", type: "website" },
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
