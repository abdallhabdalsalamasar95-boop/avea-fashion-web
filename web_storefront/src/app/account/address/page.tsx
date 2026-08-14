"use client";

import Link from "next/link";
import { ArrowRight, Check, MapPin, ShieldCheck } from "lucide-react";
import { FormEvent, useCallback, useEffect, useState } from "react";
import { DeliveryLocationFields } from "@/components/delivery-location-fields";
import { useAuth } from "@/components/auth-provider";
import { CheckoutCustomer } from "@/lib/types";
import { readCustomerProfile, writeCustomerProfile } from "@/lib/customer-storage";

const emptyProfile: CheckoutCustomer = { name: "", phone: "", address: "", city: "طرابلس", area: "" };

export default function AddressPage() {
  const { user, loading: authLoading } = useAuth();
  const [profile, setProfile] = useState<CheckoutCustomer>(emptyProfile);
  const [saved, setSaved] = useState(false);
  const changeProfile = useCallback((value: CheckoutCustomer) => {
    setProfile(value);
    setSaved(false);
  }, []);

  useEffect(() => {
    if (authLoading) return;
    const storedProfile = readCustomerProfile(user?.uid);
    setProfile(storedProfile ? { ...emptyProfile, ...storedProfile } : emptyProfile);
    setSaved(false);
  }, [authLoading, user]);

  const save = (event: FormEvent) => {
    event.preventDefault();
    writeCustomerProfile(profile, user?.uid);
    setSaved(true);
  };

  if (authLoading) return <div className="page-loading" role="status" aria-live="polite">جاري تحميل عنوانك...</div>;

  return <div className="container inner-page address-page">
    <Link className="address-back-link" href="/account/"><ArrowRight aria-hidden="true" /> العودة إلى حسابي</Link>
    <header className="address-page-head">
      <span><MapPin aria-hidden="true" /></span>
      <div><small>بيانات التوصيل</small><h1>عنواني</h1><p>أدخلي عنوانك مرة واحدة لتعبئة طلباتك القادمة بسرعة.</p></div>
    </header>

    <section className="address-form-card">
      <form onSubmit={save} className="account-form address-form">
        <label><span>الاسم الكامل</span><input required autoComplete="name" value={profile.name} onChange={(event) => { setProfile({ ...profile, name: event.target.value }); setSaved(false); }} /></label>
        <label><span>رقم الهاتف</span><input required dir="ltr" inputMode="tel" autoComplete="tel" placeholder="+218..." value={profile.phone} onChange={(event) => { setProfile({ ...profile, phone: event.target.value }); setSaved(false); }} /></label>
        <DeliveryLocationFields value={profile} onChange={changeProfile} />
        <label className="full"><span>العنوان بالتفصيل</span><input required autoComplete="street-address" placeholder="الشارع، أقرب نقطة دالة..." value={profile.address} onChange={(event) => { setProfile({ ...profile, address: event.target.value }); setSaved(false); }} /></label>
        <div className="address-form-actions">
          <button className="primary-button" type="submit">{saved ? <><Check aria-hidden="true" /> تم حفظ العنوان</> : "حفظ العنوان"}</button>
          {saved && <Link href="/account/"><ArrowRight aria-hidden="true" /> العودة إلى حسابي</Link>}
        </div>
      </form>
      <p className="address-save-status" role="status" aria-live="polite">{saved ? "تم حفظ عنوان التوصيل بنجاح." : ""}</p>
      <p className="address-privacy"><ShieldCheck aria-hidden="true" /> {user ? "يُحفظ العنوان لهذا الحساب ويستخدم لتعبئة طلباتك القادمة." : "يُحفظ العنوان على هذا الجهاز ويستخدم لتعبئة طلباتك القادمة."}</p>
    </section>
  </div>;
}
