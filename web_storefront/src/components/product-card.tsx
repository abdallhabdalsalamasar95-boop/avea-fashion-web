"use client";

import Link from "next/link";
import { Heart, ShoppingBag } from "lucide-react";
import { useStore } from "@/components/store-provider";
import { animateProductToCart } from "@/lib/cart-animation";
import { Product } from "@/lib/types";

const money = (value: number) => new Intl.NumberFormat("ar-LY", { maximumFractionDigits: 0 }).format(value);

export function ProductCard({ product }: { product: Product }) {
  const { isFavorite, toggleFavorite, addToCart } = useStore();
  const favorite = isFavorite(product.id);
  const soldOut = product.outOfStock || product.availableStock === 0;

  const discount = product.oldPrice && product.oldPrice > product.price
    ? Math.round((1 - product.price / product.oldPrice) * 100)
    : 0;

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

  const imgUrl = product.imageUrl ?? (product.imageUrls && product.imageUrls[0]) ?? "/icon.png";

  return (
    <article className="bg-white rounded-2xl overflow-hidden border border-gray-100 shadow-sm flex flex-col justify-between w-full">
      {/* قسم الصورة */}
      <div className="relative aspect-[3/4] w-full bg-gray-50 overflow-hidden">
        <Link href={`/product/?id=${encodeURIComponent(product.id)}`} className="block w-full h-full">
          <img 
            src={imgUrl} 
            alt={product.name} 
            className="w-full h-full object-cover object-center"
          />
        </Link>
        
        {/* شارة NEW أو الخصم فوق الصورة */}
        <div className="absolute top-2 right-2 z-10">
          {discount > 0 ? (
            <span className="bg-red-600 text-white text-[10px] font-bold px-2 py-0.5 rounded uppercase">
              -{discount}%
            </span>
          ) : (
            <span className="bg-black text-white text-[10px] font-bold px-2 py-0.5 rounded uppercase">
              NEW
            </span>
          )}
        </div>

        {soldOut && (
          <div className="absolute inset-0 bg-black/40 text-white text-xs font-bold flex items-center justify-center">
            نفد المخزون
          </div>
        )}
      </div>

      {/* تفاصيل المنتج */}
      <div className="p-2.5 flex flex-col gap-1.5 flex-grow justify-between">
        <div className="space-y-0.5">
          {/* اسم المنتج (سطر واحد) */}
          <Link href={`/product/?id=${encodeURIComponent(product.id)}`}>
            <h3 className="text-xs font-semibold text-gray-800 truncate" title={product.name}>
              {product.name}
            </h3>
          </Link>
        </div>

        {/* السعر */}
        <div className="flex items-baseline gap-1.5 dir-rtl">
          <span className="text-sm font-bold text-black">{money(product.price)} د.ل</span>
          {product.oldPrice && product.oldPrice > product.price && (
            <del className="text-[10px] text-gray-400">{money(product.oldPrice)} د.ل</del>
          )}
        </div>

        {/* الأزرار */}
        <div className="flex items-center gap-1.5 pt-1">
          {/* زر المفضلة */}
          <button
            onClick={() => toggleFavorite(product.id)}
            className={`p-1.5 rounded-lg border transition-colors flex items-center justify-center shrink-0 ${
              favorite 
                ? "border-red-500 bg-red-50 text-red-500" 
                : "border-gray-200 text-gray-700"
            }`}
            aria-label="المفضلة"
          >
            <Heart className={`w-4 h-4 ${favorite ? "fill-current" : ""}`} />
          </button>

          {/* زر أضف للسلة */}
          {product.sizes?.length > 0 || product.colors?.length > 0 ? (
            <Link
              href={`/product/?id=${encodeURIComponent(product.id)}`}
              className="flex-1 bg-black text-white text-[11px] font-medium py-1.5 px-2 rounded-lg flex items-center justify-center gap-1"
            >
              <ShoppingBag className="w-3.5 h-3.5 shrink-0" />
              <span>أضف للسلة</span>
            </Link>
          ) : (
            <button
              onClick={quickAdd}
              disabled={soldOut}
              className="flex-1 bg-black text-white text-[11px] font-medium py-1.5 px-2 rounded-lg flex items-center justify-center gap-1 disabled:bg-gray-300"
            >
              <ShoppingBag className="w-3.5 h-3.5 shrink-0" />
              <span>{soldOut ? "نفد" : "أضف للسلة"}</span>
            </button>
          )}
        </div>
      </div>
    </article>
  );
}
