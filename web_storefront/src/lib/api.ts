import {
  AmbassadorOrder,
  AmbassadorProfile,
  AmbassadorShare,
  AmbassadorWithdrawalRequest,
  AmbassadorWithdrawalSummary,
  AppContent,
  CartItem,
  CheckoutCustomer,
  ExternalDeliveryTracking,
  OrderProductLine,
  OrderStatus,
  Product,
  SavedCustomerOrder,
  SharedCartSelection,
  ShipmentTimelineEvent,
  TrackedOrder,
} from "@/lib/types";

const DEFAULT_API_BASE_URL =
  typeof window !== "undefined" &&
  (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1")
    ? "https://carmenkarla-backend.onrender.com"
    : "https://carmenkarla-backend.onrender.com";

export const API_BASE_URL = (
  process.env.NEXT_PUBLIC_API_BASE_URL || DEFAULT_API_BASE_URL
).replace(/\/$/, "");

const cleanOption = (value: unknown): string =>
  String(value).trim().replace(/^[\s[\]"']+|[\s[\]"']+$/g, "").trim();

const list = (value: unknown): string[] => {
  if (Array.isArray(value)) return [...new Set(value.map(cleanOption).filter(Boolean))];
  if (typeof value !== "string") return [];
  try {
    const decoded = JSON.parse(value);
    if (Array.isArray(decoded)) return list(decoded);
  } catch {
    // The API also stores some option lists as comma-separated strings.
  }
  return [...new Set(value.split(/[,،\n\r]+/).map(cleanOption).filter(Boolean))];
};

const quantityMap = (value: unknown): Record<string, number> => {
  let source = value;
  if (typeof source === "string") {
    try {
      source = JSON.parse(source);
    } catch {
      return {};
    }
  }
  if (!source || typeof source !== "object" || Array.isArray(source)) return {};
  const normalized: Record<string, number> = {};
  for (const [rawKey, rawQuantity] of Object.entries(source)) {
    const key = cleanOption(rawKey);
    if (key) normalized[key] = Math.max(0, Number(rawQuantity) || 0);
  }
  return normalized;
};

const bool = (value: unknown): boolean =>
  value === true || value === 1 || value === "1" || value === "true";

export const normalizeProduct = (raw: Record<string, unknown>): Product => {
  const imageUrls = list(raw.imageUrls);
  const imageUrl = typeof raw.imageUrl === "string" ? raw.imageUrl : undefined;
  if (imageUrl && !imageUrls.includes(imageUrl)) imageUrls.unshift(imageUrl);

  return {
    id: String(raw.id ?? raw.productId ?? ""),
    productCode: raw.productCode ? String(raw.productCode) : undefined,
    name: String(raw.name ?? raw.title ?? "منتج بدون اسم"),
    price: Number(raw.price ?? 0),
    oldPrice: raw.oldPrice ? Number(raw.oldPrice) : undefined,
    imageUrl,
    imageUrls,
    realImageUrl: raw.realImageUrl ? String(raw.realImageUrl) : undefined,
    description: raw.description ? String(raw.description) : undefined,
    category: raw.category ? String(raw.category) : "تشكيلة أڤيا",
    tags: raw.tags ? String(raw.tags) : undefined,
    rating: raw.rating ? Number(raw.rating) : undefined,
    reviewsCount: raw.reviewsCount ? Number(raw.reviewsCount) : undefined,
    soldPieces: Number(raw.soldPieces ?? 0),
    sizes: list(raw.sizes),
    lengths: list(raw.lengths),
    colors: list(raw.colors),
    sizeQuantities: quantityMap(raw.sizeQuantities),
    colorQuantities: quantityMap(raw.colorQuantities),
    availableStock: Number(raw.availableStock ?? raw.stockQuantity ?? 0),
    stockQuantity: Number(raw.stockQuantity ?? raw.availableStock ?? 0),
    outOfStock: bool(raw.outOfStock),
    commissionPercent: raw.commissionPercent
      ? Number(raw.commissionPercent)
      : undefined,
    createdAt: raw.createdAt ? Number(raw.createdAt) : undefined,
  };
};

async function getJson(path: string, signal?: AbortSignal): Promise<unknown> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    signal,
    headers: { Accept: "application/json" },
    cache: "no-store",
  });
  if (!response.ok) throw new Error(`تعذر الاتصال بالخادم (${response.status})`);
  return response.json();
}

export async function fetchProducts(signal?: AbortSignal): Promise<Product[]> {
  const payload = await getJson("/products", signal);
  const root = payload as Record<string, unknown>;
  const rows = Array.isArray(payload)
    ? payload
    : Array.isArray(root.items)
      ? root.items
      : Array.isArray(root.products)
        ? root.products
        : [];
  return rows
    .filter((row): row is Record<string, unknown> => Boolean(row && typeof row === "object"))
    .map(normalizeProduct)
    // A product with no price would otherwise be orderable for 0 د.ل.
    .filter((product) => product.id && product.price > 0);
}

export async function fetchAppContent(signal?: AbortSignal): Promise<AppContent> {
  const payload = await getJson("/app/content", signal);
  const root = payload as Record<string, unknown>;
  return ((root.content ?? root.data ?? payload) as AppContent) || {};
}

export async function fetchDeliveryDestinations(signal?: AbortSignal): Promise<Record<string, string[]>> {
  const payload = await getJson("/delivery/darb-sabeel/destinations", signal);
  const cities = record((payload as Record<string, unknown>).cities);
  return Object.fromEntries(
    Object.entries(cities)
      .map(([city, areas]) => [cleanOption(city), Array.from(new Set(list(areas).map((area) => area === "المدينة القديمة" ? "المدينة" : area)))] as const)
      .filter(([city, areas]) => city && areas.length),
  );
}

export async function fetchShippingCost(
  city: string,
  area: string,
  signal?: AbortSignal,
): Promise<{ amount: number; source: "api" | "fallback"; providerAvailable: boolean }> {
  const payload = record(
    await getJson(
      `/delivery/darb-sabeel/shipping-cost?city=${encodeURIComponent(city)}&area=${encodeURIComponent(area)}`,
      signal,
    ),
  );
  return {
    amount: Number(payload.amount ?? 0),
    source: String(payload.source ?? "fallback") === "api" ? "api" : "fallback",
    providerAvailable: payload.providerAvailable === true,
  };
}

export async function submitOrder(order: Record<string, unknown>, idToken?: string): Promise<{ orderId: string; trackingToken: string }> {
  const response = await fetch(`${API_BASE_URL}/orders`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify(order),
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) {
    throw new Error(String(payload.error ?? payload.message ?? "تعذر إرسال الطلب"));
  }
  return { orderId: String(payload.orderId ?? order.orderId), trackingToken: String(payload.trackingToken ?? "") };
}

export async function createAmbassadorShare(idToken: string): Promise<AmbassadorShare> {
  const response = await fetch(`${API_BASE_URL}/ambassadors/me/share-token`, {
    method: "POST",
    headers: { Accept: "application/json", Authorization: `Bearer ${idToken}` },
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) throw new Error(String(payload.error ?? "تعذر إنشاء رابط المشاركة"));
  return {
    token: String(payload.token ?? ""),
    ambassadorName: String(payload.ambassadorName ?? ""),
    expiresAt: Number(payload.expiresAt ?? 0),
  };
}

export async function fetchAmbassadorShare(token: string, signal?: AbortSignal): Promise<AmbassadorShare> {
  const response = await fetch(`${API_BASE_URL}/ambassador-shares/${encodeURIComponent(token)}`, {
    signal,
    cache: "no-store",
    headers: { Accept: "application/json" },
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) throw new Error(String(payload.error ?? "رابط الطلب غير صالح"));
  return {
    token,
    ambassadorName: String(payload.ambassadorName ?? ""),
    expiresAt: Number(payload.expiresAt ?? 0),
  };
}

const orderStatuses: OrderStatus[] = ["pending", "processing", "shipped", "postponed", "delivered", "canceled", "returning", "returned"];

const statusFromProvider = (value: unknown): OrderStatus | null => {
  const status = String(value ?? "").trim().toLowerCase().replace(/[\s-]+/g, "_");
  if (["postponed", "deferred", "delayed", "rescheduled", "on_hold", "hold", "مؤجل", "مؤجلة", "مؤجله"].includes(status)) return "postponed";
  if (["canceled", "cancelled", "deleted", "ملغي", "ملغية", "ملغى", "ملغاة"].includes(status)) return "canceled";
  if (["returning", "return_in_progress"].includes(status)) return "returning";
  if (["returned", "return_completed"].includes(status)) return "returned";
  if (["shipped", "dispatched", "out_for_delivery", "in_transit", "picked_up", "processing"].includes(status)) return "shipped";
  if (["completed", "released", "delivered"].includes(status)) return "delivered";
  if (["booked", "assigned", "accepted", "confirmed", "received"].includes(status)) return "processing";
  if (status === "pending") return "pending";
  return null;
};

const forwardChain: OrderStatus[] = ["pending", "processing", "shipped", "delivered"];

// Darb Al Sabeel leaves a shipment "pending" after a branch booked or picked it
// up, so timeline events decide the furthest step the customer has reached.
const eventStep: Record<string, OrderStatus> = {
  booked: "processing",
  accepted: "processing",
  referenced: "processing",
  assigned: "shipped",
  picked_up: "shipped",
  shipped: "shipped",
  out_for_delivery: "shipped",
  in_transit: "shipped",
  delivered: "delivered",
  completed: "delivered",
};

const normalizedOrderStatus = (value: unknown, delivery?: ExternalDeliveryTracking): OrderStatus => {
  const providerStatus = statusFromProvider(delivery?.providerStatus ?? delivery?.status);
  if (providerStatus && !forwardChain.includes(providerStatus)) return providerStatus;

  const fallback = String(value ?? "pending") as OrderStatus;
  const local = orderStatuses.includes(fallback) ? fallback : "pending";
  const base = providerStatus ?? (forwardChain.includes(local) ? local : null);
  if (!base) return local;

  let furthest = forwardChain.indexOf(base);
  for (const event of delivery?.timeline ?? []) {
    const step = eventStep[String(event.type ?? "").trim().toLowerCase().replace(/[\s-]+/g, "_")];
    if (step) furthest = Math.max(furthest, forwardChain.indexOf(step));
  }
  return forwardChain[furthest];
};

const normalizeDeliveryTracking = (value: unknown): ExternalDeliveryTracking => {
  const source = record(value);
  return {
    provider: source.provider == null ? undefined : String(source.provider),
    status: source.status == null ? undefined : String(source.status),
    shipmentId: source.shipmentId == null ? undefined : String(source.shipmentId),
    trackingNumber: source.trackingNumber == null ? undefined : String(source.trackingNumber),
    courierPhone: source.courierPhone == null ? undefined : String(source.courierPhone),
    referenceCode: source.referenceCode == null ? undefined : String(source.referenceCode),
    providerStatus: source.providerStatus == null ? undefined : String(source.providerStatus),
    syncStatus: source.syncStatus == null ? undefined : String(source.syncStatus),
    lastError: source.lastError == null ? undefined : String(source.lastError),
    lastSyncAtMs: source.lastSyncAtMs == null ? undefined : Number(source.lastSyncAtMs),
    timeline: Array.isArray(source.timeline) ? source.timeline.map((raw) => {
      const event = record(raw);
      return {
        id: event.id == null ? undefined : String(event.id),
        type: String(event.type ?? "info"),
        descriptionAr: event.descriptionAr == null ? undefined : String(event.descriptionAr),
        descriptionEn: event.descriptionEn == null ? undefined : String(event.descriptionEn),
        timestamp: event.timestamp == null ? undefined : String(event.timestamp),
      };
    }) : [],
  };
};

export async function fetchOrderTracking(orderId: string, trackingToken: string, signal?: AbortSignal): Promise<TrackedOrder> {
  const payload = record(await getJson(`/orders/${encodeURIComponent(orderId)}/tracking?token=${encodeURIComponent(trackingToken)}`, signal));
  const item = record(payload.item);
  const externalDelivery = normalizeDeliveryTracking(item.externalDelivery);
  return {
    orderId: String(item.orderId ?? orderId),
    status: normalizedOrderStatus(item.status, externalDelivery),
    createdAtMs: Number(item.createdAtMs ?? 0),
    updatedAtMs: Number(item.updatedAtMs ?? 0),
    externalDelivery,
    ambassadorPhone: String(item.ambassadorPhone ?? "") || undefined,
    statusReason: String(item.statusReason ?? "") || undefined,
    statusReasonImageUrl: String(item.statusReasonImageUrl ?? "") || undefined,
  };
}

export async function fetchCustomerOrders(idToken: string, signal?: AbortSignal): Promise<SavedCustomerOrder[]> {
  const response = await fetch(`${API_BASE_URL}/customers/me/orders?limit=500`, {
    signal,
    cache: "no-store",
    headers: { Accept: "application/json", Authorization: `Bearer ${idToken}` },
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) throw new Error(String(payload.error ?? "تعذر تحميل طلبات الحساب"));
  return Array.isArray(payload.items) ? payload.items.map<SavedCustomerOrder>((value) => {
    const row = record(value);
    const externalDelivery = normalizeDeliveryTracking(row.externalDelivery);
    return {
      orderId: String(row.orderId ?? ""),
      createdAt: Number(row.createdAtMs ?? 0),
      total: Number(row.grandTotal ?? 0),
      itemCount: Number(row.itemsCount ?? 0),
      status: normalizedOrderStatus(row.status, externalDelivery),
      trackingToken: row.trackingToken == null ? undefined : String(row.trackingToken),
      externalDelivery,
      ambassadorPhone: String(row.ambassadorPhone ?? "") || undefined,
      statusReason: String(row.statusReason ?? "") || undefined,
      statusReasonImageUrl: String(row.statusReasonImageUrl ?? "") || undefined,
      items: normalizeOrderItems(row.items),
      orderChannel: row.orderChannel === "ambassador" ? "ambassador" : "customer",
    };
  }).filter((order) => order.orderId) : [];
}

async function cancelOwnedOrder(kind: "customers" | "ambassadors", orderId: string, idToken: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/${kind}/me/orders/${encodeURIComponent(orderId)}/cancel`, {
    method: "POST",
    headers: { Accept: "application/json", Authorization: `Bearer ${idToken}` },
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) {
    throw new Error(String(payload.error ?? "تعذر إلغاء الطلب الآن"));
  }
}

export async function cancelCustomerOrder(orderId: string, idToken: string): Promise<void> {
  return cancelOwnedOrder("customers", orderId, idToken);
}

export async function cancelAmbassadorOrder(orderId: string, idToken: string): Promise<void> {
  return cancelOwnedOrder("ambassadors", orderId, idToken);
}

const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};

const normalizeOrderItems = (value: unknown) => (Array.isArray(value) ? value : []).map((item) => {
  const line = record(item);
  return {
    productId: String(line.productId ?? line.id ?? ""),
    productCode: line.productCode == null ? undefined : String(line.productCode),
    name: String(line.name ?? line.title ?? "موديل بدون اسم"),
    imageUrl: line.imageUrl == null ? undefined : String(line.imageUrl),
    size: line.size == null ? undefined : cleanOption(line.size),
    length: line.length == null ? undefined : cleanOption(line.length),
    color: line.color == null ? undefined : cleanOption(line.color),
    price: Number(line.price ?? 0),
    quantity: Number(line.quantity ?? 0),
    commissionPercent: line.commissionPercent == null ? undefined : Number(line.commissionPercent),
  };
});

const normalizeAmbassadorOrder = (value: unknown): AmbassadorOrder => {
  const row = record(value);
  const payload = record(row.payload);
  const customer = record(payload.customer);
  const pricing = record(payload.pricing);
  const items = normalizeOrderItems(payload.items);
  const rawStatus = String(row.status ?? "pending");
  const status: AmbassadorOrder["status"] = orderStatuses.includes(rawStatus as OrderStatus)
    ? rawStatus as AmbassadorOrder["status"]
    : "pending";
  const summary = record(row.ambassadorSummary);
  return {
    orderId: String(row.orderId ?? ""),
    status,
    createdAtMs: Number(row.createdAtMs ?? 0),
    updatedAtMs: Number(row.updatedAtMs ?? row.createdAtMs ?? 0),
    customerName: String(row.customerName ?? customer.name ?? ""),
    customerPhone: String(row.customerPhone ?? customer.phone ?? ""),
    customerAddress: String(row.customerAddress ?? customer.address ?? ""),
    customerCity: String(row.customerCity ?? row.city ?? customer.city ?? ""),
    grandTotal: Number(row.grandTotal ?? pricing.grandTotal ?? 0),
    itemsCount: Number(row.itemsCount ?? items.reduce((sum, item) => sum + item.quantity, 0)),
    payload: { items },
    ambassadorSummary: {
      estimatedCommission: Number(summary.estimatedCommission ?? 0),
      grossSales: Number(summary.grossSales ?? 0),
      commissionPercent: Number(summary.commissionPercent ?? 0),
    },
    externalDelivery: normalizeDeliveryTracking(row.externalDelivery),
    ambassadorPhone: String(row.ambassadorPhone ?? summary.ambassadorPhone ?? customer.submitterPhone ?? "") || undefined,
    statusReason: String(row.statusReason ?? "") || undefined,
    statusReasonImageUrl: String(row.statusReasonImageUrl ?? "") || undefined,
  };
};

export async function fetchAmbassadorOrders(idToken: string, uid: string, signal?: AbortSignal): Promise<AmbassadorOrder[]> {
  let response = await fetch(`${API_BASE_URL}/ambassadors/me/orders?limit=500`, {
    signal,
    cache: "no-store",
    headers: { Accept: "application/json", Authorization: `Bearer ${idToken}` },
  });
  if (response.status === 404) {
    response = await fetch(`${API_BASE_URL}/orders/feed?limit=500&uid=${encodeURIComponent(uid)}`, {
      signal,
      cache: "no-store",
      headers: { Accept: "application/json" },
    });
  }
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) {
    throw new Error(String(payload.error ?? "تعذر تحميل لوحة المندوب"));
  }
  return Array.isArray(payload.items)
    ? payload.items.map(normalizeAmbassadorOrder).filter((item) => item.orderId)
    : [];
}

const normalizeWithdrawalRequest = (value: unknown): AmbassadorWithdrawalRequest => {
  const row = record(value);
  const rawStatus = String(row.status ?? "pending");
  const status: AmbassadorWithdrawalRequest["status"] = ["pending", "approved", "paid", "rejected"].includes(rawStatus)
    ? rawStatus as AmbassadorWithdrawalRequest["status"]
    : "pending";
  return {
    id: String(row.id ?? ""),
    amount: Number(row.amount ?? 0),
    status,
    createdAtMs: Number(row.createdAtMs ?? 0),
    updatedAtMs: Number(row.updatedAtMs ?? row.createdAtMs ?? 0),
  };
};

const normalizeWithdrawalSummary = (payload: Record<string, unknown>): AmbassadorWithdrawalSummary => ({
  minimum: Number(payload.minimum ?? 100),
  earned: Number(payload.earned ?? 0),
  reserved: Number(payload.reserved ?? 0),
  available: Number(payload.available ?? 0),
  remainingToMinimum: Number(payload.remainingToMinimum ?? 0),
  canRequest: payload.canRequest === true,
  pendingRequest: payload.pendingRequest ? normalizeWithdrawalRequest(payload.pendingRequest) : null,
  requests: Array.isArray(payload.requests) ? payload.requests.map(normalizeWithdrawalRequest).filter((item) => item.id) : [],
});

async function ambassadorWithdrawalRequest(method: "GET" | "POST", idToken: string, signal?: AbortSignal): Promise<AmbassadorWithdrawalSummary> {
  const response = await fetch(`${API_BASE_URL}/ambassadors/me/withdrawals`, {
    method,
    signal,
    cache: "no-store",
    headers: { Accept: "application/json", Authorization: `Bearer ${idToken}` },
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok || payload.ok === false) {
    throw new Error(String(payload.error ?? "تعذر تحديث بيانات السحب"));
  }
  return normalizeWithdrawalSummary(payload);
}

export async function fetchAmbassadorWithdrawals(idToken: string, signal?: AbortSignal): Promise<AmbassadorWithdrawalSummary> {
  return ambassadorWithdrawalRequest("GET", idToken, signal);
}

export async function submitAmbassadorWithdrawal(idToken: string): Promise<AmbassadorWithdrawalSummary> {
  return ambassadorWithdrawalRequest("POST", idToken);
}
