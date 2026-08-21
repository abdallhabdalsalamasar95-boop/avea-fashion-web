"use client";

import Link from "next/link";
import { Heart, ShoppingBag } from "lucide-react";
import { useAmbassador } from "@/components/ambassador-context";
import { AmbassadorShareButton } from "@/components/ambassador-share-button";
import { ProductImage } from "@/components/product-image";
import { useStore } from "@/components/store-provider";
import { lineCommission } from "@/lib/commission";
import { animateProductToCart } from "@/lib/cart-animation";
import { Product } from "@/lib/types";

const money = (value: number) => new Intl.NumberFormat("ar-LY", { maximumFractionDigits: 2 }).format(value);

export function ProductCard({ product }: { product: Product }) {
  const { isFavorite, toggleFavorite, addToCart } = useStore();
  const { ambassador, commission } = useAmbassador();
  const favorite = isFavorite(product.id);
  const soldOut = product.outOfStock || product.availableStock === 0;
  const discount = product.oldPrice && product.oldPrice > product.price
    ? Math.round((1 - product.price / product.oldPrice) * 100)
    : 0;
  const ambassadorCommission = lineCommission({ ...product, quantity: 1 }, commission);

  const quickAdd = (event: React.MouseEvent<HTMLButtonElement>) => {
    addToCart({
      lineId: `${product.id}___`,
      productId: product.id,
      productCode: product.productCode,
      name: product.name,
      price: product.price,
      imageUrl: product.imageUrl ?? product.imageUrls[0],
      category: product.category,
      tags: product.tags,
      quantity: 1,
      availableStock: product.availableStock,
      commissionPercent: product.commissionPercent,
    });
    animateProductToCart(event.currentTarget);
  };

  return (
    <article className="product-card">
      <div className="product-media">
        <Link href={`/product/?id=${encodeURIComponent(product.id)}`} aria-label={`عرض ${product.name}`}>
          <ProductImage src={product.imageUrl ?? product.imageUrls[0]} alt={product.name} />
        </Link>
        {discount > 0 && <span className="sale-badge">-{discount}%</span>}
        {soldOut && <span className="stock-badge">نفد المخزون</span>}
        <div className="product-media-actions">
          <button className={favorite ? "product-card-favorite active" : "product-card-favorite"} onClick={() => toggleFavorite(product.id)} aria-label={favorite ? "إزالة من المفضلة" : "إضافة للمفضلة"} title={favorite ? "إزالة من المفضلة" : "إضافة للمفضلة"}>
            <Heart fill={favorite ? "currentColor" : "none"} />
          </button>
          <AmbassadorShareButton
            className="product-card-share"
            title={product.name}
            text={ambassador ? `اختيار خاص لكِ من شريك Carmen Karla المعتمد ${ambassador.ambassadorName}. شاهدي التفاصيل وأكملي طلبك بكل سهولة.` : `شاهدي هذا المنتج المميز من Carmen Karla.`}
            label="مشاركة المنتج"
            compact
            buildPath={(token) => `/product/?id=${encodeURIComponent(product.id)}${token ? `&ref=${encodeURIComponent(token)}` : ""}`}
          />
        </div>
      </div>
      <div className="product-info">
        <div className="product-card-summary">
          <div className="product-card-copy">
            <Link href={`/product/?id=${encodeURIComponent(product.id)}`}><h3>{product.name}</h3></Link>
            <div className="price"><strong>{money(product.price)} د.ل</strong>{product.oldPrice && product.oldPrice > product.price && <del>{money(product.oldPrice)} د.ل</del>}</div>
          </div>
          {ambassador && <small className="product-commission"><i>عمولتك</i><strong>{money(ambassadorCommission)} د.ل</strong></small>}
        </div>
        {product.sizes.length > 0 || product.colors.length > 0
          ? <Link className="product-card-cart-action" href={`/product/?id=${encodeURIComponent(product.id)}`}><ShoppingBag /> اختاري التفاصيل</Link>
          : <button className="product-card-cart-action" onClick={quickAdd} disabled={soldOut}><ShoppingBag /> {soldOut ? "نفد المخزون" : "أضيفي للسلة"}</button>}
      </div>
    </article>
  );
}
