"use client";

import Link from "next/link";
import { ChevronLeft, Heart, MapPin, PackageCheck, RefreshCw, ShoppingBag } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { OrderStatus, SavedCustomerOrder } from "@/lib/types";
import { AuthPanel } from "@/components/auth-panel";
import { useAuth } from "@/components/auth-provider";
import { OrderCard } from "@/components/order-card";
import { OrderFilterToolbar, OrderStatusFilter, SortOrder, TimeframeFilter } from "@/components/order-filter-toolbar";
import { useStore } from "@/components/store-provider";
import { CartItem } from "@/lib/types";
import { cancelCustomerOrder, fetchCustomerOrders, fetchOrderTracking } from "@/lib/api";
import { readCustomerOrders, writeCustomerOrders } from "@/lib/customer-storage";

const normalizedStatus = (value: unknown): OrderStatus => {
  const status = String(value ?? "pending") as OrderStatus;
  return ["pending", "processing", "shipped", "postponed", "delivered", "canceled", "returning", "returned"].includes(status) ? status : "pending";
};

export default function AccountPage() {
  const { user, loading: authLoading } = useAuth();
  const { addToCart } = useStore();
  const [orders, setOrders] = useState<SavedCustomerOrder[]>([]);
  const [statusFilter, setStatusFilter] = useState<OrderStatusFilter>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [timeframe, setTimeframe] = useState<TimeframeFilter>("all");
  const [sortOrder, setSortOrder] = useState<SortOrder>("newest");
  const [syncing, setSyncing] = useState(false);
  const [syncMessage, setSyncMessage] = useState("");
  const [cancelingOrderId, setCancelingOrderId] = useState("");
  const [reorderingOrderId, setReorderingOrderId] = useState("");

  const reorder = (order: SavedCustomerOrder) => {
    if (!order.items?.length) return;
    setReorderingOrderId(order.orderId);
    order.items.forEach((item, index) => {
      if (!item.productId) return;
      addToCart({
        lineId: `${item.productId}_${item.size ?? ""}_${item.color ?? ""}_${index}`,
        productId: item.productId,
        productCode: item.productCode,
        name: item.name || "منتج",
        price: Number(item.price ?? 0),
        imageUrl: item.imageUrl,
        size: item.size,
        length: item.length,
        color: item.color,
        quantity: Math.max(1, Number(item.quantity ?? 1)),
      } satisfies CartItem);
    });
    setSyncMessage("تمت إضافة منتجات الطلب إلى السلة.");
    window.setTimeout(() => setReorderingOrderId(""), 350);
  };

  const cancelOrder = async (orderId: string) => {
    if (!user || cancelingOrderId || !window.confirm("هل تريدين إلغاء هذا الطلب؟ لا يمكن التراجع بعد الإلغاء.")) return;
    setCancelingOrderId(orderId);
    setSyncMessage("");
    try {
      await cancelCustomerOrder(orderId, await user.getIdToken());
      const next = orders.map((order) => order.orderId === orderId ? { ...order, status: "canceled" as const, statusReason: "تم إلغاء الطلب بناءً على طلب العميلة." } : order);
      setOrders(next);
      writeCustomerOrders(next, user.uid);
      setSyncMessage("تم إلغاء الطلب بنجاح.");
    } catch (reason) {
      setSyncMessage(reason instanceof Error ? reason.message : "تعذر إلغاء الطلب الآن.");
    } finally {
      setCancelingOrderId("");
    }
  };

  useEffect(() => {
    if (authLoading) return;
    let active = true;
    let currentOrders: SavedCustomerOrder[] = readCustomerOrders(user?.uid).filter((order) => order.orderChannel !== "ambassador").map((order) => ({ ...order, status: normalizedStatus(order.status) }));
    setOrders(currentOrders);
    setStatusFilter("all");

    const refresh = async () => {
      setSyncing(true);
      try {
        const next = user
          ? await fetchCustomerOrders(await user.getIdToken())
          : await Promise.all(currentOrders.map(async (order) => {
            if (!order.trackingToken) return order;
            try {
              const tracked = await fetchOrderTracking(order.orderId, order.trackingToken);
              return { ...order, status: tracked.status, externalDelivery: tracked.externalDelivery, ambassadorPhone: tracked.ambassadorPhone, statusReason: tracked.statusReason, statusReasonImageUrl: tracked.statusReasonImageUrl };
            } catch {
              return order;
            }
          }));
        if (!active) return;
        currentOrders = next.map((order) => ({ ...order, ownerUid: user?.uid, status: normalizedStatus(order.status) }));
        setOrders(currentOrders);
        writeCustomerOrders(currentOrders, user?.uid);
        setSyncMessage("");
      } catch {
        if (active) setSyncMessage("تعذر التحديث الآن، نعرض آخر بيانات محفوظة.");
      } finally {
        if (active) setSyncing(false);
      }
    };
    void refresh();
    const timer = window.setInterval(() => void refresh(), 15000);
    return () => { active = false; window.clearInterval(timer); };
  }, [authLoading, user]);

  const counts = useMemo(() => ({
    all: orders.length,
    active: orders.filter((order) => ["pending", "processing", "shipped", "returning"].includes(order.status)).length,
    completed: orders.filter((order) => ["delivered", "returned"].includes(order.status)).length,
    postponed: orders.filter((order) => order.status === "postponed").length,
    canceled: orders.filter((order) => order.status === "canceled").length,
  }), [orders]);

  const filteredOrders = useMemo(() => {
    let list = [...orders];

    // Status Filter
    if (statusFilter === "active") {
      list = list.filter((order) => ["pending", "processing", "shipped", "returning"].includes(order.status));
    } else if (statusFilter === "completed") {
      list = list.filter((order) => ["delivered", "returned"].includes(order.status));
    } else if (statusFilter === "postponed") {
      list = list.filter((order) => order.status === "postponed");
    } else if (statusFilter === "canceled") {
      list = list.filter((order) => order.status === "canceled");
    }

    // Search Query (orderId, items name, productCode)
    const q = searchQuery.trim().toLowerCase();
    if (q) {
      list = list.filter((order) => {
        const orderIdMatch = order.orderId.toLowerCase().includes(q) || order.orderId.replace(/^o_/, "").slice(-8).toLowerCase().includes(q);
        const itemMatch = (order.items || []).some((it) => (it.name || "").toLowerCase().includes(q) || (it.productCode || "").toLowerCase().includes(q));
        const courierMatch = (order.externalDelivery?.courierPhone || "").includes(q);
        return orderIdMatch || itemMatch || courierMatch;
      });
    }

    // Timeframe Filter
    const now = Date.now();
    if (timeframe === "today") {
      const startOfDay = new Date().setHours(0, 0, 0, 0);
      list = list.filter((order) => order.createdAt >= startOfDay);
    } else if (timeframe === "week") {
      const oneWeekAgo = now - 7 * 24 * 60 * 60 * 1000;
      list = list.filter((order) => order.createdAt >= oneWeekAgo);
    } else if (timeframe === "month") {
      const oneMonthAgo = now - 30 * 24 * 60 * 60 * 1000;
      list = list.filter((order) => order.createdAt >= oneMonthAgo);
    } else if (timeframe === "three_months") {
      const threeMonthsAgo = now - 90 * 24 * 60 * 60 * 1000;
      list = list.filter((order) => order.createdAt >= threeMonthsAgo);
    }

    // Sort Order
    if (sortOrder === "newest") {
      list.sort((a, b) => b.createdAt - a.createdAt);
    } else if (sortOrder === "oldest") {
      list.sort((a, b) => a.createdAt - b.createdAt);
    } else if (sortOrder === "highest_price") {
      list.sort((a, b) => (b.total || 0) - (a.total || 0));
    }

    return list;
  }, [orders, statusFilter, searchQuery, timeframe, sortOrder]);

  const summaryStats = useMemo(() => {
    const delivered = filteredOrders.filter((o) => o.status === "delivered");
    return {
      totalSales: filteredOrders.reduce((sum, o) => sum + (o.total || 0), 0),
      deliveredCount: delivered.length,
      canceledCount: filteredOrders.filter((o) => o.status === "canceled").length,
    };
  }, [filteredOrders]);

  const handleResetFilters = () => {
    setStatusFilter("all");
    setSearchQuery("");
    setTimeframe("all");
    setSortOrder("newest");
  };

  return <div className="container inner-page account-page">
    <div className="page-title account-title"><span>مساحتك الخاصة</span><h1>حسابي وطلباتي</h1></div>
    <AuthPanel />
    <div className="account-grid">
      <div className="account-quick-links">
        <Link className="account-address-link" href="/account/address/" aria-label="فتح عنواني لإضافة أو تعديل بيانات التوصيل">
          <span className="account-address-icon"><MapPin aria-hidden="true" /></span>
          <span className="account-address-copy"><strong>عنواني</strong><em>بيانات التوصيل</em></span>
          <ChevronLeft aria-hidden="true" />
        </Link>
        <Link className="account-address-link" href="/favorites/" aria-label="فتح المفضلة">
          <span className="account-address-icon"><Heart aria-hidden="true" /></span>
          <span className="account-address-copy"><strong>المفضلة</strong><em>القطع المحفوظة</em></span>
          <ChevronLeft aria-hidden="true" />
        </Link>
      </div>

      <section className="account-card orders-card" id="orders">
        <div className="account-card-title orders-title"><div><PackageCheck /></div><span><small>{user ? "طلبات هذا الحساب فقط" : "طلبات الضيف على هذا الجهاز"}</small><h2>طلباتي</h2></span><i className={syncing ? "syncing" : ""}><RefreshCw /></i></div>
        {syncMessage && <p className="orders-sync-message">{syncMessage}</p>}
        {orders.length > 0 && (
          <OrderFilterToolbar
            statusFilter={statusFilter}
            onStatusChange={setStatusFilter}
            counts={counts}
            searchQuery={searchQuery}
            onSearchChange={setSearchQuery}
            searchPlaceholder="بحث برقم الطلب أو اسم القطعة..."
            timeframe={timeframe}
            onTimeframeChange={setTimeframe}
            sortOrder={sortOrder}
            onSortChange={setSortOrder}
            onReset={handleResetFilters}
            totalFilteredCount={filteredOrders.length}
            totalOriginalCount={orders.length}
          />
        )}
        {orders.length === 0 ? (
          <div className="account-empty"><ShoppingBag /><h3>لا توجد طلبات لهذا الحساب</h3><p>{user ? "أي طلب تسجلينه بهذا الحساب سيظهر هنا وحده، ولن تظهر طلبات الحسابات الأخرى." : "بعد إتمام أول طلب كضيفة سيظهر رقمه وحالته هنا."}</p><Link className="secondary-button" href="/#collection">ابدئي التسوق</Link></div>
        ) : filteredOrders.length === 0 ? (
          <div className="orders-filter-empty">
            <PackageCheck />
            <h3>لا توجد طلبات تطابق هذا التصنيف حاليًا</h3>
            <p>جربي تغيير خيارات الفلتر أو البحث لعرض باقي الطلبات.</p>
            <button type="button" className="secondary-button reset-filter-action" onClick={handleResetFilters}>إعادة ضبط الفلاتر</button>
          </div>
        ) : (
          <div className="saved-orders">{filteredOrders.map((order) => <OrderCard key={order.orderId} orderId={order.orderId} status={order.status} createdAt={order.createdAt} total={order.total} itemCount={order.itemCount} items={order.items} delivery={order.externalDelivery} trackingToken={order.trackingToken} ambassadorPhone={order.ambassadorPhone} statusReason={order.statusReason} statusReasonImageUrl={order.statusReasonImageUrl} onReorder={order.status === "canceled" ? () => reorder(order) : undefined} reordering={reorderingOrderId === order.orderId} onCancel={["pending", "processing"].includes(order.status) ? () => void cancelOrder(order.orderId) : undefined} canceling={cancelingOrderId === order.orderId} compact />)}</div>
        )}
      </section>
    </div>
  </div>;
}
