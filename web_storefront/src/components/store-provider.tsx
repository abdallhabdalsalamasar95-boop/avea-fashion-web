"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { CartItem } from "@/lib/types";

type StoreContextValue = {
  cart: CartItem[];
  storeReady: boolean;
  favorites: string[];
  cartCount: number;
  total: number;
  addToCart: (item: CartItem) => void;
  replaceCart: (items: CartItem[]) => void;
  updateQuantity: (lineId: string, quantity: number) => void;
  removeFromCart: (lineId: string) => void;
  clearCart: () => void;
  toggleFavorite: (productId: string) => void;
  isFavorite: (productId: string) => boolean;
};

const StoreContext = createContext<StoreContextValue | null>(null);
const CART_KEY = "avea.web.cart.v1";
const FAVORITES_KEY = "avea.web.favorites.v1";

const cleanOption = (value: unknown): string =>
  String(value ?? "").trim().replace(/^[\s[\]"']+|[\s[\]"']+$/g, "").trim().toLocaleLowerCase();

export function cartItemMaximum(item: CartItem): number | undefined {
  if (item.size && item.sizeQuantities) {
    const wanted = cleanOption(item.size);
    const match = Object.entries(item.sizeQuantities).find(([size]) => cleanOption(size) === wanted);
    if (match) return Math.max(0, Math.floor(Number(match[1]) || 0));
  }
  if (item.availableStock !== undefined) {
    return Math.max(0, Math.floor(Number(item.availableStock) || 0));
  }
  return undefined;
}

function readStorage<T>(key: string, fallback: T): T {
  try {
    const value = localStorage.getItem(key);
    return value ? (JSON.parse(value) as T) : fallback;
  } catch {
    return fallback;
  }
}

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [cart, setCart] = useState<CartItem[]>([]);
  const [favorites, setFavorites] = useState<string[]>([]);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setCart(readStorage(CART_KEY, []));
    setFavorites(readStorage(FAVORITES_KEY, []));
    setReady(true);
  }, []);

  useEffect(() => {
    if (ready) localStorage.setItem(CART_KEY, JSON.stringify(cart));
  }, [cart, ready]);

  useEffect(() => {
    if (ready) localStorage.setItem(FAVORITES_KEY, JSON.stringify(favorites));
  }, [favorites, ready]);

  const value = useMemo<StoreContextValue>(() => ({
    cart,
    storeReady: ready,
    favorites,
    cartCount: cart.reduce((sum, item) => sum + item.quantity, 0),
    total: cart.reduce((sum, item) => sum + item.price * item.quantity, 0),
    addToCart: (item) => setCart((current) => {
      const existing = current.find((entry) => entry.lineId === item.lineId);
      return existing
        ? current.map((entry) => entry.lineId === item.lineId
          ? (() => {
            const merged = { ...entry, ...item, quantity: entry.quantity + item.quantity };
            const maximum = cartItemMaximum(merged);
            return { ...merged, quantity: maximum === undefined ? merged.quantity : Math.min(maximum, merged.quantity) };
          })()
          : entry)
        : [...current, item];
    }),
      replaceCart: (items) => setCart(items),
    updateQuantity: (lineId, quantity) => setCart((current) =>
      quantity < 1
        ? current.filter((item) => item.lineId !== lineId)
        : current.map((item) => {
          if (item.lineId !== lineId) return item;
          const maximum = cartItemMaximum(item);
          return { ...item, quantity: maximum === undefined ? quantity : Math.min(maximum, quantity) };
        })),
    removeFromCart: (lineId) => setCart((current) => current.filter((item) => item.lineId !== lineId)),
    clearCart: () => setCart([]),
    toggleFavorite: (productId) => setFavorites((current) =>
      current.includes(productId)
        ? current.filter((id) => id !== productId)
        : [...current, productId]),
    isFavorite: (productId) => favorites.includes(productId),
  }), [cart, favorites, ready]);

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useStore() {
  const value = useContext(StoreContext);
  if (!value) throw new Error("useStore must be used within StoreProvider");
  return value;
}
