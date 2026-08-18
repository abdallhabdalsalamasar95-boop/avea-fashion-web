"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchDeliveryDestinations } from "@/lib/api";
import { CheckoutCustomer } from "@/lib/types";

const fallbackCities = ["طرابلس", "بنغازي", "مصراتة", "الزاوية", "زليتن", "الخمس", "سرت", "سبها", "البيضاء", "درنة", "طبرق"];

type Props = {
  value: CheckoutCustomer;
  onChange: (value: CheckoutCustomer) => void;
};

export function DeliveryLocationFields({ value, onChange }: Props) {
  const [destinations, setDestinations] = useState<Record<string, string[]>>({});
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
    const available = Object.keys(destinations);
    const source = available.length ? available : fallbackCities;
    return value.city && !source.includes(value.city) ? [value.city, ...source] : source;
  }, [destinations, value.city]);
  const areas = useMemo(() => destinations[value.city] ?? [], [destinations, value.city]);

  useEffect(() => {
    if (areas.length && value.area && !areas.includes(value.area)) {
      onChange({ ...value, area: "" });
    }
  }, [areas, onChange, value]);

  return <>
    <label><span>المدينة *</span><select required value={value.city} onChange={(event) => onChange({ ...value, city: event.target.value, area: "" })}>
      {cities.map((city) => <option key={city} value={city}>{city}</option>)}
    </select></label>
    <label><span>المنطقة *</span>{areas.length
      ? <select required autoComplete="address-level3" value={value.area} onChange={(event) => onChange({ ...value, area: event.target.value })}>
          <option value="">اختاري المنطقة</option>
          {areas.map((area) => <option key={area} value={area}>{area}</option>)}
        </select>
      : <input required autoComplete="address-level3" placeholder={loading ? "جاري تحميل المناطق..." : "اكتبي المنطقة"} value={value.area} onChange={(event) => onChange({ ...value, area: event.target.value })} />}
      {!loading && !providerAvailable && <small className="location-provider-note">تعذر تحميل القائمة الآن، يمكنكِ كتابة المنطقة يدويًا.</small>}
    </label>
  </>;
}
