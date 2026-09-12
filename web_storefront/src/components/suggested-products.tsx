"use client";

import Link from "next/link";
import { Sparkles } from "lucide-react";
import { useEffect, useState } from "react";
import { ProductImage } from "@/components/product-image";
import { fetchProducts } from "@/lib/api";
import { Product } from "@/lib/types";

interface SuggestedProductsProps {
  currentProductId?: string;
  category?: string;
  title?: string;
  subtitle?: string;
  limit?: number;
  className?: string;
}

const money = (value: number) => new Intl.NumberFormat("ar-LY", { maximumFractionDigits: 2 }).format(value);

export function SuggestedProducts({
  currentProductId,
  category,
  title = "موديلات قد تعجبك",
  subtitle = "اكتشفي قطعًا متناسقة ومختارة بعناية لتكمل إطلالتك",
  limit = 4,
  className = "",
}: SuggestedProductsProps) {
  const [items, setItems] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    const controller = new AbortController();

    fetchProducts(controller.signal)
      .then((all) => {
        if (!active) return;
        const available = all.filter((p) => p.id !== currentProductId && !p.outOfStock && (p.availableStock === undefined || p.availableStock > 0));
        
        // Priority scoring:
        // 1. Same category
        // 2. High rating / popular / newest
        const scored = available.map((p) => {
          let score = 0;
          if (category && p.category && p.category.trim() === category.trim()) {
            score += 10;
          }
          if (p.oldPrice && p.oldPrice > p.price) {
            score += 2;
          }
          return { product: p, score };
        });

        scored.sort((a, b) => b.score - a.score);
        setItems(scored.slice(0, limit).map((s) => s.product));
      })
      .catch(() => {
        if (active) setItems([]);
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
      controller.abort();
    };
  }, [currentProductId, category, limit]);

  if (loading) {
    return (
      <section className={`suggested-models-section ${className}`}>
        <div className="suggested-models-header">
          <div className="suggested-models-badge"><Sparkles /> {title}</div>
          {subtitle && <p className="suggested-models-subtitle">{subtitle}</p>}
        </div>
        <div className="suggested-models-grid skeleton-grid">
          {Array.from({ length: limit }).map((_, i) => (
            <div key={i} className="suggested-card-skeleton">
              <div className="skeleton-media" />
              <div className="skeleton-line title" />
              <div className="skeleton-line price" />
            </div>
          ))}
        </div>
      </section>
    );
  }

  if (!items.length) return null;

  return (
    <section className={`suggested-models-section ${className}`}>
      <div className="suggested-models-header">
        <div className="suggested-models-badge"><Sparkles /> {title}</div>
        {subtitle && <p className="suggested-models-subtitle">{subtitle}</p>}
      </div>
      <div className="suggested-models-grid">
        {items.map((item) => {
          const discount = item.oldPrice && item.oldPrice > item.price
            ? Math.round((1 - item.price / item.oldPrice) * 100)
            : 0;
          return (
            <Link
              key={item.id}
              href={`/product/?id=${encodeURIComponent(item.id)}`}
              className="suggested-product-card"
            >
              <div className="suggested-media">
                <ProductImage
                  src={item.imageUrl ?? item.imageUrls[0]}
                  alt={item.name}
                />
                {discount > 0 && <span className="suggested-discount-tag">-{discount}%</span>}
              </div>
              <div className="suggested-details">
                <h4>{item.name}</h4>
                <div className="suggested-price">
                  <strong>{money(item.price)} د.ل</strong>
                  {item.oldPrice && item.oldPrice > item.price && (
                    <del>{money(item.oldPrice)} د.ل</del>
                  )}
                </div>
                {item.sizes && item.sizes.length > 0 && (
                  <div className="suggested-sizes">
                    {item.sizes.slice(0, 4).map((s) => (
                      <span key={s} className="suggested-size-badge">{s}</span>
                    ))}
                    {item.sizes.length > 4 && <span className="suggested-size-more">+{item.sizes.length - 4}</span>}
                  </div>
                )}
              </div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}
