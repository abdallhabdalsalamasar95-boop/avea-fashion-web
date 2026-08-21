import { AmbassadorShare, CartItem, SharedCartSelection } from "@/lib/types";

export const AMBASSADOR_SHARE_SESSION_KEY = "avea.web.ambassador-share.v1";
const AMBASSADOR_SHARE_FALLBACK_TTL_SECONDS = 7 * 24 * 60 * 60;

const getStorage = (): Storage | null => {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage;
  } catch {
    try {
      return window.sessionStorage;
    } catch {
      return null;
    }
  }
};

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

export function decodeAmbassadorNameFromShareToken(token: string): string {
  try {
    const body = String(token || "").trim().split(".", 1)[0] || "";
    if (!body) return "";
    const parsed = JSON.parse(fromBase64Url(body)) as Record<string, unknown>;
    return String(parsed?.name ?? "").trim();
  } catch {
    return "";
  }
}

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
  const token = String(share?.token ?? "").trim();
  if (!token) return;
  const storage = getStorage();
  if (!storage) return;
  const previous = readAmbassadorShare();
  const ambassadorName = String(share?.ambassadorName ?? "").trim() || previous?.ambassadorName || "";
  const expiresAt = Number(share?.expiresAt ?? 0) > 0
    ? Number(share.expiresAt)
    : (previous?.expiresAt ?? Math.floor(Date.now() / 1000) + AMBASSADOR_SHARE_FALLBACK_TTL_SECONDS);
  storage.setItem(AMBASSADOR_SHARE_SESSION_KEY, JSON.stringify({ token, ambassadorName, expiresAt }));
}

/**
 * Store a referral token immediately so checkout attribution is never lost
 * while the verification request is still in-flight.
 */
export function seedAmbassadorShareToken(token: string): void {
  const clean = String(token || "").trim();
  if (!clean) return;
  const hintedName = decodeAmbassadorNameFromShareToken(clean);
  saveAmbassadorShare({
    token: clean,
    ambassadorName: readAmbassadorShare()?.ambassadorName || hintedName,
    expiresAt: Math.floor(Date.now() / 1000) + AMBASSADOR_SHARE_FALLBACK_TTL_SECONDS,
  });
}

export function readAmbassadorShare(): AmbassadorShare | null {
  try {
    const storage = getStorage();
    if (!storage) return null;
    const share = JSON.parse(storage.getItem(AMBASSADOR_SHARE_SESSION_KEY) || "null") as AmbassadorShare | null;
    const token = String(share?.token ?? "").trim();
    const expiresAt = Number(share?.expiresAt ?? 0);
    if (!token || !expiresAt || expiresAt * 1000 < Date.now()) {
      storage.removeItem(AMBASSADOR_SHARE_SESSION_KEY);
      return null;
    }
    return {
      token,
      ambassadorName: String(share?.ambassadorName ?? "").trim(),
      expiresAt,
    };
  } catch {
    const storage = getStorage();
    storage?.removeItem(AMBASSADOR_SHARE_SESSION_KEY);
    return null;
  }
}

export function clearAmbassadorShare(): void {
  const storage = getStorage();
  storage?.removeItem(AMBASSADOR_SHARE_SESSION_KEY);
}
