"use client";

import Link from "next/link";
import { Ban, Check, ChevronLeft, MapPin, PackageCheck, PauseCircle, RefreshCw, ShoppingBag, Truck, UserRound } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { OrderStatus, SavedCustomerOrder } from "@/lib/types";
import { AuthPanel } from "@/components/auth-panel";
import { useAuth } from "@/components/auth-provider";
import { OrderCard } from "@/components/order-card";
import { cancelCustomerOrder, fetchCustomerOrders, fetchOrderTracking } from "@/lib/api";
import { readCustomerOrders, writeCustomerOrders } from "@/lib/customer-storage";

const normalizedStatus = (value: unknown): OrderStatus => {
  const status = String(value ?? "pending") as OrderStatus;
  return ["pending", "processing", "shipped", "postponed", "delivered", "canceled", "returning", "returned"].includes(status) ? status : "pending";
};

export default function AccountPage() {
  const { user, loading: authLoading } = useAuth();
  const [orders, setOrders] = useState<SavedCustomerOrder[]>([]);
  const [filter, setFilter] = useState<"all" | "active" | "postponed" | "canceled" | "completed">("all");
  const [syncing, setSyncing] = useState(false);
  const [syncMessage, setSyncMessage] = useState("");
  const [cancelingOrderId, setCancelingOrderId] = useState("");

  const cancelOrder = async (orderId: string) => {
    if (!user || cancelingOrderId || !window.confirm("هل تريدين إلغاء هذا الطلب؟ لا يمكن التراجع بعد الإلغاء.")) return;
    setCancelingOrderId(orderId);
    setSyncMessage("");
    try {
      await cancelCustomerOrder(orderId, await user.getIdToken());
      const next = orders.map((order) => order.orderId === orderId ? { ...order, status: "canceled" as const } : order);
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
    setFilter("all");

    const refresh = async () => {
      setSyncing(true);
      try {
        const next = user
          ? await fetchCustomerOrders(await user.getIdToken())
          : await Promise.all(currentOrders.map(async (order) => {
            if (!order.trackingToken) return order;
            try {
              const tracked = await fetchOrderTracking(order.orderId, order.trackingToken);
              return { ...order, status: tracked.status, externalDelivery: tracked.externalDelivery };
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
    active: orders.filter((order) => ["pending", "processing", "shipped", "returning"].includes(order.status)).length,
    postponed: orders.filter((order) => order.status === "postponed").length,
    canceled: orders.filter((order) => order.status === "canceled").length,
    completed: orders.filter((order) => ["delivered", "returned"].includes(order.status)).length,
  }), [orders]);
  const visibleOrders = useMemo(() => orders.filter((order) => {
    if (filter === "all") return true;
    if (filter === "active") return ["pending", "processing", "shipped", "returning"].includes(order.status);
    if (filter === "completed") return ["delivered", "returned"].includes(order.status);
    return order.status === filter;
  }), [filter, orders]);

  return <div className="container inner-page account-page">
    <div className="page-title"><span>مساحتك الخاصة</span><h1>حسابي وطلباتي</h1><p>أديري عنوان التوصيل وتابعي الطلبات التي أرسلتِها.</p></div>
    <AuthPanel />
    <div className="account-grid">
      <Link className="account-address-link" href="/account/address/" aria-label="فتح عنواني لإضافة أو تعديل بيانات التوصيل">
        <span className="account-address-icon"><MapPin aria-hidden="true" /></span>
        <span className="account-address-copy"><small>بيانات التوصيل</small><strong>عنواني</strong><em>إضافة أو تعديل عنوان التوصيل</em></span>
        <ChevronLeft aria-hidden="true" />
      </Link>

      <section className="account-card orders-card" id="orders">
        <div className="account-card-title orders-title"><div><PackageCheck /></div><span><small>{user ? "طلبات هذا الحساب فقط" : "طلبات الضيف على هذا الجهاز"}</small><h2>طلباتي</h2></span><i className={syncing ? "syncing" : ""}><RefreshCw /></i></div>
        {user && <div className="account-owner-note"><UserRound /><span><small>الحساب الحالي</small><strong>{user.displayName || user.email}</strong></span><Check /></div>}
        {syncMessage && <p className="orders-sync-message">{syncMessage}</p>}
        {orders.length > 0 && <><div className="order-status-summary"><article><Truck /><span><small>جارية</small><strong>{counts.active}</strong></span></article><article className="postponed"><PauseCircle /><span><small>مؤجلة</small><strong>{counts.postponed}</strong></span></article><article className="canceled"><Ban /><span><small>ملغية</small><strong>{counts.canceled}</strong></span></article></div><div className="order-filters">{([['all', 'الكل', orders.length], ['active', 'الجارية', counts.active], ['postponed', 'المؤجلة', counts.postponed], ['canceled', 'الملغية', counts.canceled], ['completed', 'المكتملة', counts.completed]] as const).map(([value, label, count]) => <button key={value} className={filter === value ? "active" : ""} onClick={() => setFilter(value)}>{label}<b>{count}</b></button>)}</div></>}
        {orders.length === 0 ? <div className="account-empty"><ShoppingBag /><h3>لا توجد طلبات لهذا الحساب</h3><p>{user ? "أي طلب تسجلينه بهذا الحساب سيظهر هنا وحده، ولن تظهر طلبات الحسابات الأخرى." : "بعد إتمام أول طلب كضيفة سيظهر رقمه وحالته هنا."}</p><Link className="secondary-button" href="/#collection">ابدئي التسوق</Link></div>
          : visibleOrders.length === 0 ? <div className="orders-filter-empty"><PackageCheck /><p>لا توجد طلبات في هذه الحالة.</p></div>
          : <div className="saved-orders">{visibleOrders.map((order) => <OrderCard key={order.orderId} orderId={order.orderId} status={order.status} createdAt={order.createdAt} total={order.total} itemCount={order.itemCount} items={order.items} delivery={order.externalDelivery} onCancel={["pending", "processing"].includes(order.status) ? () => void cancelOrder(order.orderId) : undefined} canceling={cancelingOrderId === order.orderId} compact />)}</div>}
      </section>
    </div>
  </div>;
}
