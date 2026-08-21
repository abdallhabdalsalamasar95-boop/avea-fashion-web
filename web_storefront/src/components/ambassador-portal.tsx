"use client";

import Link from "next/link";
import { ArrowLeft, BadgeCheck, Clock3, Landmark, PackageCheck, Pencil, Phone, RefreshCw, ShoppingBag, TrendingUp, UserRound, WalletCards } from "lucide-react";
import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AuthPanel } from "@/components/auth-panel";
import { AmbassadorShareButton } from "@/components/ambassador-share-button";
import { OrderCard } from "@/components/order-card";
import { useAuth } from "@/components/auth-provider";
import { getAmbassadorProfile, saveAmbassadorProfile, validPhone } from "@/lib/ambassador-profile";
import { cancelAmbassadorOrder, fetchAmbassadorOrders, fetchAmbassadorWithdrawals, fetchAppContent, submitAmbassadorWithdrawal } from "@/lib/api";
import { CommissionConfig, lineCommission } from "@/lib/commission";
import { AmbassadorOrder, AmbassadorProfile, AmbassadorWithdrawalSummary } from "@/lib/types";

const emptyWithdrawal: AmbassadorWithdrawalSummary = {
  minimum: 100,
  earned: 0,
  reserved: 0,
  available: 0,
  remainingToMinimum: 100,
  canRequest: false,
  pendingRequest: null,
  requests: [],
};

const withdrawalStatusContent: Record<AmbassadorWithdrawalSummary["requests"][number]["status"], { label: string; message: string }> = {
  pending: {
    label: "قيد المراجعة",
    message: "طلب السحب وصل إلى الإدارة وهو قيد المراجعة.",
  },
  approved: {
    label: "تم قبول الطلب",
    message: "وافقت الإدارة على طلب السحب، وسيتم تحويل المبلغ قريبًا.",
  },
  paid: {
    label: "تم الدفع",
    message: "تم دفع مبلغ طلب السحب من الإدارة.",
  },
  rejected: {
    label: "تم رفض الطلب",
    message: "لم تتم الموافقة على طلب السحب، وعاد المبلغ إلى رصيدك المتاح.",
  },
};

function orderCommission(order: AmbassadorOrder, defaultPercent: number, perProduct: boolean): number {
  const explicit = Number(order.ambassadorSummary?.estimatedCommission ?? 0);
  if (explicit > 0) return explicit;
  const lines = order.payload?.items ?? [];
  const config: CommissionConfig = { defaultPercent, perProductEnabled: perProduct };
  if (lines.length) return lines.reduce((sum, item) => sum + lineCommission({
    price: Number(item.price ?? 0),
    quantity: Number(item.quantity ?? 0),
    commissionPercent: item.commissionPercent,
  }, config), 0);
  return order.grandTotal * defaultPercent / 100;
}

export function AmbassadorPortal() {
  const { user, loading: authLoading } = useAuth();
  const [profile, setProfile] = useState<AmbassadorProfile | null>(null);
  const [orders, setOrders] = useState<AmbassadorOrder[]>([]);
  const [commission, setCommission] = useState({ defaultPercent: 7, perProductEnabled: true });
  const [profileLoading, setProfileLoading] = useState(true);
  const [ordersLoading, setOrdersLoading] = useState(false);
  const [withdrawal, setWithdrawal] = useState<AmbassadorWithdrawalSummary>(emptyWithdrawal);
  const [withdrawalLoading, setWithdrawalLoading] = useState(false);
  const [withdrawalMessage, setWithdrawalMessage] = useState("");
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState("");
  const [cancelingOrderId, setCancelingOrderId] = useState("");
  const dashboardRequestActive = useRef(false);

  const loadDashboard = useCallback(async (showProgress = true) => {
    if (!user || dashboardRequestActive.current) return;
    dashboardRequestActive.current = true;
    if (showProgress) setOrdersLoading(true);
    setError("");
    try {
      const controller = new AbortController();
      const timer = window.setTimeout(() => controller.abort(), 8000);
      try {
        const token = await user.getIdToken();
        const [items, content, withdrawalSummary] = await Promise.all([
          fetchAmbassadorOrders(token, user.uid, controller.signal),
          fetchAppContent(controller.signal),
          fetchAmbassadorWithdrawals(token, controller.signal).catch(() => null),
        ]);
        setOrders(items);
        if (withdrawalSummary) setWithdrawal(withdrawalSummary);
        setCommission({
          defaultPercent: content.commission?.defaultPercent ?? 7,
          perProductEnabled: content.commission?.perProductEnabled !== false,
        });
      } finally {
        window.clearTimeout(timer);
      }
    } catch {
      setError("حسابك مفعّل. بيانات الطلبات ستظهر عند توفر خدمة التحديث.");
    } finally {
      dashboardRequestActive.current = false;
      setOrdersLoading(false);
    }
  }, [user]);

  const requestWithdrawal = async () => {
    if (!user || withdrawalLoading || !withdrawal.canRequest) return;
    setWithdrawalLoading(true);
    setWithdrawalMessage("");
    try {
      const token = await user.getIdToken();
      const next = await submitAmbassadorWithdrawal(token);
      setWithdrawal(next);
      setWithdrawalMessage("تم إرسال طلب السحب، وسيتم مراجعته من الإدارة.");
    } catch (reason) {
      setWithdrawalMessage(reason instanceof Error ? reason.message : "تعذر إرسال طلب السحب");
    } finally {
      setWithdrawalLoading(false);
    }
  };

  const cancelOrder = async (orderId: string) => {
    if (!user || cancelingOrderId || !window.confirm("هل تريدين إلغاء طلب هذه العميلة؟ لا يمكن التراجع بعد الإلغاء.")) return;
    setCancelingOrderId(orderId);
    setError("");
    try {
      await cancelAmbassadorOrder(orderId, await user.getIdToken());
      setOrders((current) => current.map((order) => order.orderId === orderId ? { ...order, status: "canceled" } : order));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "تعذر إلغاء الطلب الآن.");
    } finally {
      setCancelingOrderId("");
    }
  };

  useEffect(() => {
    let active = true;
    const loadProfile = async () => {
      if (!user) {
        if (active) setProfileLoading(false);
        return;
      }
      setProfileLoading(true);
      setError("");
      try {
        const savedProfile = await getAmbassadorProfile(user);
        if (!active) return;
        setProfile(savedProfile);
        setProfileLoading(false);
        if (savedProfile) void loadDashboard();
      } catch (reason) {
        if (!active) return;
        setError(reason instanceof Error ? reason.message : "تعذر تحميل حساب المندوبة");
        setProfileLoading(false);
      }
    };
    void loadProfile();
    return () => { active = false; };
  }, [user, loadDashboard]);

  useEffect(() => {
    if (!user || !profile || editing) return;
    const timer = window.setInterval(() => void loadDashboard(false), 10000);
    return () => window.clearInterval(timer);
  }, [user, profile, editing, loadDashboard]);

  const stats = useMemo(() => {
    const active = orders.filter((order) => !["canceled", "returned"].includes(order.status));
    const delivered = orders.filter((order) => order.status === "delivered");
    const pending = orders.filter((order) => !["delivered", "canceled", "returned"].includes(order.status));
    const earned = delivered.reduce((sum, order) => sum + orderCommission(order, commission.defaultPercent, commission.perProductEnabled), 0);
    const pendingCommission = pending.reduce((sum, order) => sum + orderCommission(order, commission.defaultPercent, commission.perProductEnabled), 0);
    return {
      sales: active.reduce((sum, order) => sum + order.grandTotal, 0),
      totalCommission: earned + pendingCommission,
      earned,
      pending: pendingCommission,
      delivered: delivered.length,
      deliveryRate: orders.length ? delivered.length * 100 / orders.length : 0,
    };
  }, [orders, commission]);

  const latestWithdrawalRequest = withdrawal.pendingRequest ?? withdrawal.requests[0] ?? null;
  const latestWithdrawalStatus = latestWithdrawalRequest
    ? withdrawalStatusContent[latestWithdrawalRequest.status]
    : null;

  if (authLoading || profileLoading) return <div className="ambassador-portal-loading"><span /><p>لحظة واحدة...</p></div>;
  if (!user) return <div className="ambassador-login-box"><div><UserRound /><h3>سجّلي الدخول للبدء</h3><p>أنشئي حسابًا مجانيًا، ثم أكملي ملف المندوبة خلال دقيقة.</p></div><AuthPanel /></div>;
  if (!profile || editing) return <AmbassadorApplication userEmail={user.email ?? ""} profile={profile} onCancel={profile ? () => setEditing(false) : undefined} onSaved={(next) => { setProfile(next); setEditing(false); setError(""); void loadDashboard(false); }} />;

  return <div className="ambassador-dashboard">
    <header className="ambassador-dashboard-head">
      <div><span><BadgeCheck /> حساب مندوبة نشط</span><h2>مرحبًا، {profile.ambassadorName}</h2><p>تابعي مبيعاتك وعمولاتك وحالة كل طلب من مكان واحد.</p></div>
      <div><button disabled={ordersLoading} onClick={() => void loadDashboard()}><RefreshCw className={ordersLoading ? "spin" : ""} /> {ordersLoading ? "جاري التحديث" : "تحديث"}</button><button onClick={() => setEditing(true)}><Pencil /> تعديل الملف</button><Link href="/#collection">طلب جديد لعميلة <ArrowLeft /></Link></div>
    </header>

    {error && <p className="ambassador-error">{error}</p>}
    <section className="ambassador-referral-card">
      <div><span><BadgeCheck /> رابط شراكتك</span><h3>شاركي المتجر باسمك</h3><p>أي زبونة تفتح الرابط وتطلب، يظهر لها اسمك في الصفحة الرئيسية وتُسجّل العمولة في حسابك تلقائيًا.</p></div>
      <AmbassadorShareButton buildPath={(token) => `/?ref=${encodeURIComponent(token)}`} title="شاركي واربحِي" text={`تسوّقي من Carmen Karla عن طريق شريكتنا المعتمدة ${profile.ambassadorName}.`} label="شاركي واربحِي" />
    </section>
    <div className="ambassador-stat-grid">
      <article><span><TrendingUp /></span><small>إجمالي المبيعات</small><strong>{stats.sales.toFixed(2)} د.ل</strong><em>{orders.length} طلب</em></article>
      <article className="earned"><span><WalletCards /></span><small>إجمالي أرباحك</small><strong>{stats.totalCommission.toFixed(2)} د.ل</strong><em>من كل الطلبات النشطة</em></article>
      <article><span><Clock3 /></span><small>عمولة معلقة</small><strong>{stats.pending.toFixed(2)} د.ل</strong><em>المعتمد بعد التوصيل: {stats.earned.toFixed(2)} د.ل</em></article>
      <article><span><PackageCheck /></span><small>نسبة نجاح التوصيل</small><strong>{stats.deliveryRate.toFixed(0)}%</strong><em>{stats.delivered} طلب موصّل</em></article>
    </div>

    <section className="ambassador-withdrawal-card">
      <div className="withdrawal-icon"><Landmark /></div>
      <div className="withdrawal-copy"><small>رصيد السحب</small><h3>{withdrawal.available.toFixed(2)} د.ل</h3>{latestWithdrawalRequest && latestWithdrawalStatus && <span className={`withdrawal-status ${latestWithdrawalRequest.status}`}>{latestWithdrawalStatus.label}</span>}<p>{latestWithdrawalRequest && latestWithdrawalStatus ? `طلب بقيمة ${latestWithdrawalRequest.amount.toFixed(2)} د.ل — ${latestWithdrawalStatus.message}` : withdrawal.canRequest ? "رصيدك جاهز للسحب الآن." : `باقي ${withdrawal.remainingToMinimum.toFixed(2)} د.ل لفتح طلب السحب.`}</p></div>
      <div className="withdrawal-progress" aria-label={`التقدم نحو الحد الأدنى ${withdrawal.minimum} دينار`}><span><b>الحد الأدنى</b><strong>{withdrawal.minimum.toFixed(0)} د.ل</strong></span><div><i style={{ width: `${Math.min(100, withdrawal.available * 100 / Math.max(1, withdrawal.minimum))}%` }} /></div></div>
      <button className="withdrawal-button" disabled={!withdrawal.canRequest || withdrawalLoading} onClick={() => void requestWithdrawal()}>{withdrawalLoading ? "جاري الإرسال..." : withdrawal.pendingRequest ? withdrawalStatusContent[withdrawal.pendingRequest.status].label : withdrawal.canRequest ? `سحب ${withdrawal.available.toFixed(2)} د.ل` : latestWithdrawalRequest?.status === "paid" ? "تم دفع آخر طلب" : `يتاح عند ${withdrawal.minimum.toFixed(0)} د.ل`}</button>
      {withdrawalMessage && <p className="withdrawal-message">{withdrawalMessage}</p>}
    </section>

    <div className="ambassador-dashboard-grid">
      <section className="ambassador-orders-panel">
        <div className="ambassador-panel-title"><div><small>آخر النشاط</small><h3>طلبات عميلاتك</h3></div><b>{orders.length}</b></div>
        {ordersLoading && orders.length === 0 ? <div className="ambassador-orders-loading"><span /><p>جاري تحديث الطلبات...</p></div> : orders.length === 0 ? <div className="ambassador-no-orders"><ShoppingBag /><h4>ابدئي أول عملية بيع</h4><p>اختاري المنتجات وأدخلي بيانات عميلتك عند إتمام الطلب.</p><Link href="/#collection">تصفّح المنتجات</Link></div>
          : <div className="ambassador-order-list">{orders.map((order) => <OrderCard compact key={order.orderId} orderId={order.orderId} status={order.status} createdAt={order.createdAtMs} total={order.grandTotal} itemCount={order.itemsCount} items={order.payload?.items} delivery={order.externalDelivery} customer={{ name: order.customerName, phone: order.customerPhone, city: order.customerCity, address: order.customerAddress }} footerExtra={<span className="order-card-commission">عمولتك <strong>{["canceled", "returned"].includes(order.status) ? "0.00" : orderCommission(order, commission.defaultPercent, commission.perProductEnabled).toFixed(2)} د.ل</strong></span>} onCancel={["pending", "processing"].includes(order.status) ? () => void cancelOrder(order.orderId) : undefined} canceling={cancelingOrderId === order.orderId} />)}</div>}
      </section>
      <aside className="ambassador-side-panel">
        <div className="ambassador-profile-card"><small>ملف المندوبة</small><h3>{profile.ambassadorName}</h3><p><Phone /> {profile.ambassadorPhone}</p><p>{profile.ambassadorAddress}</p><button onClick={() => setEditing(true)}>تحديث البيانات</button></div>
      </aside>
    </div>
  </div>;
}

function AmbassadorApplication({ userEmail, profile, onSaved, onCancel }: { userEmail: string; profile: AmbassadorProfile | null; onSaved: (profile: AmbassadorProfile) => void; onCancel?: () => void }) {
  const { user } = useAuth();
  const [name, setName] = useState(profile?.ambassadorName ?? "");
  const [phone, setPhone] = useState(profile?.ambassadorPhone ?? "");
  const [address, setAddress] = useState(profile?.ambassadorAddress ?? "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const submit = async (event: FormEvent) => {
    event.preventDefault(); setError("");
    if (!user) return;
    if (name.trim().length < 2) return setError("أدخلي الاسم الكامل");
    if (!validPhone(phone)) return setError("رقم الهاتف غير صحيح");
    if (address.trim().length < 4) return setError("أدخلي المدينة والمنطقة");
    setBusy(true);
    try { onSaved(await saveAmbassadorProfile(user, { ambassadorName: name, ambassadorPhone: phone, ambassadorAddress: address }, profile)); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "تعذر حفظ حساب المندوبة. حاولي مجددًا."); }
    finally { setBusy(false); }
  };
  return <div className="ambassador-application">
    <div className="ambassador-application-intro"><span>{profile ? "تعديل البيانات" : "انضمام سريع"}</span><h3>{profile ? "حدّثي بياناتك" : "فعّلي حساب المندوبة"}</h3><p>{profile ? "عدّلي البيانات ثم احفظيها." : "3 بيانات فقط، وبعدها تفتح لوحتك مباشرة."}</p>{userEmail && <small dir="ltr">{userEmail}</small>}</div>
    <form onSubmit={submit}><label><span>الاسم الكامل</span><input autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} placeholder="مثال: مريم محمد" /></label><label><span>رقم الهاتف</span><input autoComplete="tel" dir="ltr" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="09xxxxxxxx" /></label><label className="full"><span>المدينة والمنطقة</span><input autoComplete="street-address" value={address} onChange={(e) => setAddress(e.target.value)} placeholder="طرابلس - حي الأندلس" /></label>{error && <p>{error}</p>}<div>{onCancel && <button type="button" onClick={onCancel}>إلغاء</button>}<button disabled={busy}>{busy ? "لحظة واحدة..." : profile ? "حفظ التعديلات" : "تفعيل الحساب الآن"}</button></div></form>
  </div>;
}