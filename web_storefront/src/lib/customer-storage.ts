import { CheckoutCustomer, SavedCustomerOrder } from "@/lib/types";

const LEGACY_PROFILE_KEY = "avea.web.profile.v1";
const LEGACY_ORDERS_KEY = "avea.web.orders.v1";
const PROFILE_PREFIX = "avea.web.profile.v2";
const ORDERS_PREFIX = "avea.web.orders.v2";
const GUEST_SCOPE = "guest";

const scope = (uid?: string | null) => uid ? `user.${uid}` : GUEST_SCOPE;
const profileKey = (uid?: string | null) => `${PROFILE_PREFIX}.${scope(uid)}`;
const ordersKey = (uid?: string | null) => `${ORDERS_PREFIX}.${scope(uid)}`;

const parseArray = (raw: string | null): SavedCustomerOrder[] => {
  if (!raw) return [];
  try {
    const value = JSON.parse(raw);
    return Array.isArray(value) ? value.filter((item) => item && typeof item === "object") : [];
  } catch {
    return [];
  }
};

const mergeOrders = (current: SavedCustomerOrder[], incoming: SavedCustomerOrder[]) => {
  const byId = new Map<string, SavedCustomerOrder>();
  for (const order of [...incoming, ...current]) {
    if (order.orderId && !byId.has(order.orderId)) byId.set(order.orderId, order);
  }
  return [...byId.values()].sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0));
};

const migrateLegacyStorage = () => {
  const legacyOrders = parseArray(localStorage.getItem(LEGACY_ORDERS_KEY));
  if (legacyOrders.length) {
    const groups = new Map<string, SavedCustomerOrder[]>();
    for (const order of legacyOrders) {
      const owner = String(order.ownerUid ?? "").trim();
      const key = ordersKey(owner || null);
      groups.set(key, [...(groups.get(key) ?? []), order]);
    }
    for (const [key, rows] of groups) {
      localStorage.setItem(key, JSON.stringify(mergeOrders(parseArray(localStorage.getItem(key)), rows)));
    }
  }
  localStorage.removeItem(LEGACY_ORDERS_KEY);

  const legacyProfile = localStorage.getItem(LEGACY_PROFILE_KEY);
  if (legacyProfile && !localStorage.getItem(profileKey(null))) {
    localStorage.setItem(profileKey(null), legacyProfile);
  }
  localStorage.removeItem(LEGACY_PROFILE_KEY);
};

export const readCustomerProfile = (uid?: string | null): Partial<CheckoutCustomer> | null => {
  migrateLegacyStorage();
  try {
    const raw = localStorage.getItem(profileKey(uid));
    return raw ? JSON.parse(raw) as Partial<CheckoutCustomer> : null;
  } catch {
    return null;
  }
};

export const writeCustomerProfile = (profile: CheckoutCustomer, uid?: string | null) => {
  migrateLegacyStorage();
  localStorage.setItem(profileKey(uid), JSON.stringify(profile));
};

export const readCustomerOrders = (uid?: string | null): SavedCustomerOrder[] => {
  migrateLegacyStorage();
  return parseArray(localStorage.getItem(ordersKey(uid)));
};

export const writeCustomerOrders = (orders: SavedCustomerOrder[], uid?: string | null) => {
  migrateLegacyStorage();
  localStorage.setItem(ordersKey(uid), JSON.stringify(orders));
};

export const prependCustomerOrder = (order: SavedCustomerOrder, uid?: string | null) => {
  writeCustomerOrders(mergeOrders(readCustomerOrders(uid), [{ ...order, ownerUid: uid ?? undefined }]), uid);
};