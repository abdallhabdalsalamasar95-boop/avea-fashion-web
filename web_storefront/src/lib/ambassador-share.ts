import { AmbassadorShare, CartItem, SharedCartSelection } from "@/lib/types";

export const AMBASSADOR_SHARE_SESSION_KEY = "avea.web.ambassador-share.v1";

const toBase64Url = (value: string): string => {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  bytes.forEach((byte) => { binary += String.fromCharCode(byte); });
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

const fromBase64Url = (value: string): string => {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - value.length % 4) % 4);
  const binary = atob(base64);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return new TextDecoder().decode(bytes);
};

export function encodeSharedCart(cart: CartItem[]): string {
  const selections: SharedCartSelection[] = cart.map((item) => ({
    productId: item.productId,
    size: item.size || undefined,
    length: item.length || undefined,
    color: item.color || undefined,
    quantity: Math.max(1, Math.floor(item.quantity)),
  }));
  return toBase64Url(JSON.stringify(selections));
}

export function decodeSharedCart(value: string): SharedCartSelection[] {
  try {
    const decoded = JSON.parse(fromBase64Url(value)) as unknown;
    if (!Array.isArray(decoded) || decoded.length === 0 || decoded.length > 30) return [];
    return decoded.flatMap((raw) => {
      if (!raw || typeof raw !== "object") return [];
      const item = raw as Record<string, unknown>;
      const productId = String(item.productId ?? "").trim();
      if (!productId) return [];
      return [{
        productId,
        size: item.size ? String(item.size) : undefined,
        length: item.length ? String(item.length) : undefined,
        color: item.color ? String(item.color) : undefined,
        quantity: Math.min(99, Math.max(1, Math.floor(Number(item.quantity) || 1))),
      }];
    });
  } catch {
    return [];
  }
}

export function saveAmbassadorShare(share: AmbassadorShare): void {
  sessionStorage.setItem(AMBASSADOR_SHARE_SESSION_KEY, JSON.stringify(share));
}

export function readAmbassadorShare(): AmbassadorShare | null {
  try {
    const share = JSON.parse(sessionStorage.getItem(AMBASSADOR_SHARE_SESSION_KEY) || "null") as AmbassadorShare | null;
    if (!share?.token || !share.ambassadorName || share.expiresAt * 1000 < Date.now()) {
      sessionStorage.removeItem(AMBASSADOR_SHARE_SESSION_KEY);
      return null;
    }
    return share;
  } catch {
    sessionStorage.removeItem(AMBASSADOR_SHARE_SESSION_KEY);
    return null;
  }
}

export function clearAmbassadorShare(): void {
  sessionStorage.removeItem(AMBASSADOR_SHARE_SESSION_KEY);
}
