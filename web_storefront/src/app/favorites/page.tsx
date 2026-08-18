"use client";

import Link from "next/link";
import { Heart } from "lucide-react";
import { useEffect, useState } from "react";
import { ProductCard } from "@/components/product-card";
import { useStore } from "@/components/store-provider";
import { fetchProducts } from "@/lib/api";
import { Product } from "@/lib/types";

export default function FavoritesPage() {
  const { favorites } = useStore();
  const [products, setProducts] = useState<Product[]>([]);
  useEffect(() => { const controller = new AbortController(); fetchProducts(controller.signal).then(setProducts).catch(() => {}); return () => controller.abort(); }, []);
  const shown = products.filter((item) => favorites.includes(item.id));
  return <div className="container inner-page"><div className="page-title"><span>قائمتك الخاصة</span><h1>المفضلة</h1></div>{favorites.length === 0 ? <div className="empty-state"><Heart /><h3>لم تضيفي منتجات بعد</h3><p>اضغطي رمز القلب لحفظ القطع التي أعجبتك.</p><Link className="primary-button" href="/#collection">اكتشفي التشكيلة</Link></div> : shown.length === 0 ? <div className="page-loading">جاري تحميل مفضلاتك...</div> : <div className="product-grid">{shown.map((product) => <ProductCard product={product} key={product.id} />)}</div>}</div>;
}
