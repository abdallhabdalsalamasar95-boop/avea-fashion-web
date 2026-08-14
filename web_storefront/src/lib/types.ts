export interface Product {
  id: string;
  productCode?: string;
  name: string;
  price: number;
  oldPrice?: number;
  imageUrl?: string;
  imageUrls: string[];
  realImageUrl?: string;
  description?: string;
  category?: string;
  tags?: string;
  rating?: number;
  reviewsCount?: number;
  sizes: string[];
  lengths: string[];
  colors: string[];
  sizeQuantities?: Record<string, number>;
  colorQuantities?: Record<string, number>;
  availableStock?: number;
  stockQuantity?: number;
  outOfStock?: boolean;
  commissionPercent?: number;
  createdAt?: number;
}

export interface CartItem {
  lineId: string;
  productId: string;
  productCode?: string;
  name: string;
  price: number;
  imageUrl?: string;
  category?: string;
  tags?: string;
  size?: string;
  length?: string;
  color?: string;
  quantity: number;
  sizeQuantities?: Record<string, number>;
  availableStock?: number;
  sabilEnabled?: boolean;
  sabilReferenceCode?: string;
  commissionPercent?: number;
}

export interface Coupon {
  code: string;
  type: "percent" | "fixed" | "freeShipping";
  value: number;
  minSubtotal?: number;
  maxDiscount?: number;
  freeShipping?: boolean | number;
  enabled?: boolean | number;
}

export interface AppContent {
  websiteHome?: {
    announcement?: {
      text?: string;
      enabled?: boolean;
      speedSeconds?: number;
      style?: "dark" | "rose" | "gold";
    };
    banner?: {
      imageUrl?: string;
      altText?: string;
      linkUrl?: string;
      enabled?: boolean;
    };
    sectionBanner?: {
      imageUrl?: string;
      altText?: string;
      linkUrl?: string;
      enabled?: boolean;
      widthMode?: "full" | "container";
      spacing?: "tight" | "normal" | "wide";
      height?: "compact" | "medium" | "large";
    };
    categories?: Array<{
      id: string;
      title: string;
      imageUrl?: string;
      productCategoryFilter?: string;
      enabled?: boolean;
      sortOrder?: number;
    }>;
  };
  websiteAppearance?: {
    productCardSize?: "small" | "medium" | "large";
    productImageRatio?: "portrait" | "tall" | "square";
    discountCorner?: "right" | "left";
    showFavorite?: boolean;
    showShare?: boolean;
    checkoutButtonSize?: "small" | "medium";
    checkoutConfirmPosition?: "afterCustomer" | "summary";
    showHomepageCategories?: boolean;
    showOffersStrip?: boolean;
    showNewestSection?: boolean;
    showBestSellingSection?: boolean;
  };
  ambassadorSupport?: {
    whatsappNumber?: string;
    enabled?: boolean;
  };
  offers?: {
    title?: string;
    subtitle?: string;
    items?: Array<{ id: string; text: string; enabled?: boolean }>;
  };
  coupons?: Coupon[];
  commission?: { defaultPercent?: number; perProductEnabled?: boolean };
}

export interface CheckoutCustomer {
  name: string;
  phone: string;
  address: string;
  city: string;
  area: string;
}

export interface AmbassadorShare {
  token: string;
  ambassadorName: string;
  expiresAt: number;
}

export interface SharedCartSelection {
  productId: string;
  size?: string;
  length?: string;
  color?: string;
  quantity: number;
}

export type OrderStatus = "pending" | "processing" | "shipped" | "postponed" | "delivered" | "canceled" | "returning" | "returned";

export interface ShipmentTimelineEvent {
  id?: string;
  type: string;
  descriptionAr?: string;
  descriptionEn?: string;
  timestamp?: string;
}

export interface ExternalDeliveryTracking {
  provider?: string;
  status?: string;
  shipmentId?: string;
  trackingNumber?: string;
  referenceCode?: string;
  providerStatus?: string;
  syncStatus?: string;
  lastSyncAtMs?: number;
  timeline?: ShipmentTimelineEvent[];
}

export interface TrackedOrder {
  orderId: string;
  status: OrderStatus;
  createdAtMs: number;
  updatedAtMs: number;
  externalDelivery: ExternalDeliveryTracking;
}

export interface OrderProductLine {
  productId?: string;
  productCode?: string;
  name?: string;
  imageUrl?: string;
  size?: string;
  length?: string;
  color?: string;
  price?: number;
  quantity?: number;
  commissionPercent?: number;
}

export interface SavedCustomerOrder {
  orderId: string;
  createdAt: number;
  total: number;
  itemCount: number;
  status: OrderStatus;
  trackingToken?: string;
  externalDelivery?: ExternalDeliveryTracking;
  ownerUid?: string;
  items?: OrderProductLine[];
  orderChannel?: "customer" | "ambassador";
}

export interface AmbassadorProfile {
  uid: string;
  accountRole: "ambassador";
  ambassadorName: string;
  ambassadorPhone: string;
  ambassadorAddress: string;
  email: string;
  status: "active";
  joinedAt: number;
  updatedAt: number;
}

export interface AmbassadorOrder {
  orderId: string;
  status: OrderStatus;
  createdAtMs: number;
  updatedAtMs: number;
  customerName: string;
  customerPhone: string;
  customerAddress: string;
  customerCity: string;
  grandTotal: number;
  itemsCount: number;
  payload?: {
    items?: OrderProductLine[];
  };
  ambassadorSummary?: {
    estimatedCommission?: number;
    grossSales?: number;
    commissionPercent?: number;
  };
  externalDelivery?: ExternalDeliveryTracking;
}

export interface AmbassadorWithdrawalRequest {
  id: string;
  amount: number;
  status: "pending" | "approved" | "paid" | "rejected";
  createdAtMs: number;
  updatedAtMs: number;
}

export interface AmbassadorWithdrawalSummary {
  minimum: number;
  earned: number;
  reserved: number;
  available: number;
  remainingToMinimum: number;
  canRequest: boolean;
  pendingRequest: AmbassadorWithdrawalRequest | null;
  requests: AmbassadorWithdrawalRequest[];
}
