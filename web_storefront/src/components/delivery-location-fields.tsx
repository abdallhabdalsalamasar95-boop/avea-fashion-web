"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchDeliveryDestinations } from "@/lib/api";
import { CheckoutCustomer } from "@/lib/types";

const fallbackCities = ["طرابلس", "بنغازي", "مصراتة", "الزاوية", "زليتن", "الخمس", "سرت", "سبها", "البيضاء", "درنة", "طبرق"];
const fallbackAreas: Record<string, string[]> = { طرابلس: ["المدينة"] };

// Darb Sabeel lists many towns as areas under a nearby branch city, so search must match both levels.
const normalize = (value: string) => value
  .replace(/[\u064B-\u0652\u0640]/g, "")
  .replace(/[أإآٱ]/g, "ا")
  .replace(/ى/g, "ي")
  .replace(/ة/g, "ه")
  .replace(/\s+/g, " ")
  .trim()
  .toLowerCase();

type Props = {
  value: CheckoutCustomer;
  onChange: (value: CheckoutCustomer) => void;
};

export function DeliveryLocationFields({ value, onChange }: Props) {
  const [destinations, setDestinations] = useState<Record<string, string[]>>({});
  const [loading, setLoading] = useState(true);
  const [providerAvailable, setProviderAvailable] = useState(true);
  const [query, setQuery] = useState("");

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
  const areas = useMemo(() => destinations[value.city] ?? fallbackAreas[value.city] ?? [], [destinations, value.city]);

  const matches = useMemo(() => {
    const term = normalize(query);
    if (term.length < 2) return [];
    const found: { city: string; area: string }[] = [];
    for (const [city, cityAreas] of Object.entries(destinations)) {
      for (const area of cityAreas) {
        if (normalize(area).includes(term) || normalize(city).includes(term)) found.push({ city, area });
        if (found.length >= 30) break;
      }
    }
    return found.slice(0, 8);
  }, [destinations, query]);

  useEffect(() => {
    if (areas.length && value.area && !areas.includes(value.area)) {
      onChange({ ...value, area: "" });
    }
  }, [areas, onChange, value]);

  return <>
    <label className="full destination-search">
      <span>ابحثي عن مدينتك أو منطقتك</span>
      <input
        type="search"
        autoComplete="off"
        placeholder="اكتبي اسم المنطقة، مثل: زليتن أو سلوق"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      {matches.length > 0 && <ul className="destination-results">
        {matches.map(({ city, area }) => <li key={`${city}-${area}`}>
          <button type="button" onClick={() => { onChange({ ...value, city, area }); setQuery(""); }}>
            <strong>{area}</strong><small>{city}</small>
          </button>
        </li>)}
      </ul>}
      {normalize(query).length >= 2 && matches.length === 0 && !loading && <small className="location-provider-note">لا توجد نتيجة مطابقة، اختاري المدينة والمنطقة يدويًا.</small>}
    </label>
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
