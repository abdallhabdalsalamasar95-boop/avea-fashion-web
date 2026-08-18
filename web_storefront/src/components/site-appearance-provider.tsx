"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { fetchAppContent } from "@/lib/api";
import { AppContent } from "@/lib/types";

type Appearance = NonNullable<AppContent["websiteAppearance"]>;

const defaults: Required<Appearance> = {
  productCardSize: "small",
  productImageRatio: "portrait",
  discountCorner: "right",
  showFavorite: true,
  showShare: true,
  checkoutButtonSize: "small",
  checkoutConfirmPosition: "afterCustomer",
  showHomepageCategories: true,
  showOffersStrip: true,
  showNewestSection: true,
  showBestSellingSection: true,
};

const AppearanceContext = createContext<Required<Appearance>>(defaults);

export function SiteAppearanceProvider({ children }: { children: React.ReactNode }) {
  const [appearance, setAppearance] = useState<Required<Appearance>>(defaults);

  useEffect(() => {
    fetchAppContent()
      .then((content) => setAppearance({ ...defaults, ...content.websiteAppearance }))
      .catch(() => {});
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    root.dataset.productCardSize = appearance.productCardSize;
    root.dataset.productImageRatio = appearance.productImageRatio;
    root.dataset.discountCorner = appearance.discountCorner;
    root.dataset.showFavorite = String(appearance.showFavorite);
    root.dataset.showShare = String(appearance.showShare);
    root.dataset.checkoutButtonSize = appearance.checkoutButtonSize;
    root.dataset.checkoutConfirmPosition = appearance.checkoutConfirmPosition;
  }, [appearance]);

  const value = useMemo(() => appearance, [appearance]);
  return <AppearanceContext.Provider value={value}>{children}</AppearanceContext.Provider>;
}

export const useSiteAppearance = () => useContext(AppearanceContext);