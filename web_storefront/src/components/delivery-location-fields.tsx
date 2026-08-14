"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchDeliveryDestinations } from "@/lib/api";
import { CheckoutCustomer } from "@/lib/types";

const fallbackDestinations: Record<string, string[]> = {
  طرابلس: ["وسط طرابلس", "تاجوراء", "جنزور", "سوق الجمعة", "حي الأندلس", "عين زارة", "أبو سليم"],
  بنغازي: ["وسط بنغازي", "الحدائق", "الهواري", "سيدي حسين", "الليثي"],
  مصراتة: ["وسط مصراتة", "الدافنية", "زريق"],
  الزاوية: ["الزاوية", "الزاوية المركز", "الحرشة"],
  صرمان: ["صرمان", "الجميل", "العجيلات"],
  صبراتة: ["صبراتة", "زلطن", "رقدالين"],
  زوارة: ["زوارة", "أبو كماش"],
  غريان: ["غريان", "الأصابعة", "ككلة"],
  الزنتان: ["الزنتان", "يفرن", "الرياينة"],
  "الجبل الغربي": ["يفرن", "ككلة", "القلعة", "الزنتان", "الرياينة", "وازن", "نالوت", "جادو", "الرجبان", "تيجي", "مزو"],
  يفرن: ["يفرن", "القواسم", "القلعة", "الحرابة"],
  ككلة: ["ككلة", "القلعة", "يفرن"],
  نالوت: ["نالوت", "وازن", "تيجي", "غدامس"],
  جادو: ["جادو", "تمسين", "فساطو"],
  غدامس: ["غدامس", "درج", "سيناون"],
  البيضاء: ["البيضاء", "شحات", "سوسة", "الحمامة"],
  درنة: ["درنة", "القبة", "التميمي"],
  طبرق: ["طبرق", "مساعد", "امساعد"],
  أجدابيا: ["أجدابيا", "البريقة", "العقيلة"],
  المرج: ["المرج", "الأبيار", "توكرة"],
  سرت: ["وسط سرت", "هراوة", "بن جواد"],
  زليتن: ["وسط زليتن", "الجميل", "كعام"],
  الخمس: ["وسط الخمس", "مسلاتة", "قصر خيار"],
  ترهونة: ["ترهونة", "مسلاتة", "القربولي"],
  "بني وليد": ["بني وليد", "وادي دينار", "المردوم"],
  "القره بوللي": ["القره بوللي", "سيدي خليفة", "القويعة"],
  سبها: ["وسط سبها", "الجديد", "القرضة"],
  مرزق: ["مرزق", "القطرون", "تراغن"],
  أوباري: ["أوباري", "غات", "وادي عتبة"],
  غات: ["غات", "العوينات", "البركت"],
  جالو: ["جالو", "أوجلة", "إجخرة"],
  أوجلة: ["أوجلة", "جالو", "إجخرة"],
  الكفرة: ["الكفرة", "رُبيانة", "التازربو"],
};

const fallbackCities = Object.keys(fallbackDestinations);

type Props = {
  value: CheckoutCustomer;
  onChange: (value: CheckoutCustomer) => void;
};

export function DeliveryLocationFields({ value, onChange }: Props) {
  const [destinations, setDestinations] = useState<Record<string, string[]>>({});
  const [citySearch, setCitySearch] = useState("");
  const [areaSearch, setAreaSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [providerAvailable, setProviderAvailable] = useState(true);

  useEffect(() => {
    const controller = new AbortController();
    fetchDeliveryDestinations(controller.signal)
      .then((cities) => {
        setDestinations(cities);
        setProviderAvailable(Object.keys(cities).length > 0);
      })
      .catch((reason: unknown) => {
        if (!(reason instanceof DOMException && reason.name === "AbortError")) setProviderAvailable(false);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, []);

  const cities = useMemo(() => {
    const source = Array.from(new Set([...fallbackCities, ...Object.keys(destinations)]));
    return value.city && !source.includes(value.city) ? [value.city, ...source] : source;
  }, [destinations, value.city]);
  const filteredCities = useMemo(() => cities.filter((city) => city.includes(citySearch.trim())), [cities, citySearch]);
  const areas = useMemo(() => Array.from(new Set([...(fallbackDestinations[value.city] ?? []), ...(destinations[value.city] ?? [])])), [destinations, value.city]);
  const filteredAreas = useMemo(() => areas.filter((area) => area.includes(areaSearch.trim())), [areas, areaSearch]);

  useEffect(() => {
    if (areas.length && value.area && !areas.includes(value.area)) {
      onChange({ ...value, area: "" });
    }
  }, [areas, onChange, value]);

  return <>
    <label><span>المدينة *</span><input className="location-search-input" type="search" value={citySearch} onChange={(event) => setCitySearch(event.target.value)} placeholder="ابحثي عن مدينة..." /><select required value={value.city} onChange={(event) => { onChange({ ...value, city: event.target.value, area: "" }); setAreaSearch(""); }}>
      {filteredCities.length ? filteredCities.map((city) => <option key={city} value={city}>{city}</option>) : <option value="">لا توجد مدينة مطابقة</option>}
    </select></label>
    <label><span>المنطقة *</span>{areas.length
      ? <><input className="location-search-input" type="search" value={areaSearch} onChange={(event) => setAreaSearch(event.target.value)} placeholder="ابحثي عن منطقة..." /><select required autoComplete="address-level3" value={value.area} onChange={(event) => onChange({ ...value, area: event.target.value })}>
          <option value="">اختاري المنطقة</option>
          {filteredAreas.map((area) => <option key={area} value={area}>{area}</option>)}
        </select></>
      : <input required autoComplete="address-level3" placeholder={loading ? "جاري تحميل المناطق..." : "اكتبي المنطقة"} value={value.area} onChange={(event) => onChange({ ...value, area: event.target.value })} />}
      {!loading && !providerAvailable && <small className="location-provider-note">تعذر تحميل القائمة الآن، يمكنكِ كتابة المنطقة يدويًا.</small>}
    </label>
  </>;
}
