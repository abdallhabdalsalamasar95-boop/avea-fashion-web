"use client";

import Link from "next/link";
import { Heart, ShoppingBag, Star } from "lucide-react";
import { useAmbassador } from "@/components/ambassador-context";
import { ProductImage } from "@/components/product-image";
import { useStore } from "@/components/store-provider";
import { animateProductToCart } from "@/lib/cart-animation";
import { Product } from "@/lib/types";

const money = (value: number) => new Intl.NumberFormat("ar-LY", { maximumFractionDigits: 0 }).format(value);

export function ProductCard({ product }: { product: Product }) {
  const { isFavorite, toggleFavorite, addToCart } = useStore();
  const favorite = isFavorite(product.id);
  const soldOut = product.outOfStock || product.availableStock === 0;
  
  // الخصم
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

  return (
    <article className="bg-white rounded-2xl overflow-hidden border border-gray-100 shadow-sm hover:shadow-md transition-all flex flex-col justify-between">
      {/* قسم الصورة */}
      <div className="relative aspect-[4/5] bg-gray-50 overflow-hidden group">
        <Link href={`/product/?id=${encodeURIComponent(product.id)}`} className="block w-full h-full">
          <ProductImage src={product.imageUrl ?? product.imageUrls[0]} alt={product.name} />
        </Link>
        
        {/* شارة جديد / الخصم في أعلى اليمين مثل الصورة */}
        <div className="absolute top-2 right-2 flex flex-col gap-1 z-10">
          {discount > 0 ? (
            <span className="bg-red-600 text-white text-[10px] font-bold px-2.5 py-1 rounded-md uppercase tracking-wider">
              -{discount}%
            </span>
          ) : (
            <span className="bg-black text-white text-[10px] font-bold px-2.5 py-1 rounded-md uppercase tracking-wider">
              NEW
            </span>
          )}
        </div>

        {soldOut && (
          <span className="absolute inset-0 bg-black/40 text-white text-xs font-bold flex items-center justify-center backdrop-blur-[1px]">
            نفد المخزون
          </span>
        )}
      </div>

      {/* تفاصيل المنتج */}
      <div className="p-3 flex flex-col gap-2 flex-grow justify-between">
        <div className="space-y-1">
          {/* التقييم: يظهر فقط إذا كان موجوداً في بيانات المنتج */}
          {(product as any).rating && (
            <div className="flex items-center gap-1 text-amber-500 text-xs font-bold">
              <Star className="w-3.5 h-3.5 fill-current" />
              <span>{Number((product as any).rating).toFixed(2)}</span>
            </div>
          )}

          {/* اسم المنتج (محدد بسطر واحد للتحكم في الطول) */}
          <Link href={`/product/?id=${encodeURIComponent(product.id)}`}>
            <h3 className="text-xs font-semibold text-gray-800 truncate hover:text-black transition-colors" title={product.name}>
              {product.name}
            </h3>
          </Link>

          {/* الوصف القصير إن وجد (سطر واحد خفيف) */}
          {product.description && (
            <p className="text-[11px] text-gray-400 truncate">
              {product.description}
            </p>
          )}
        </div>

        {/* السعر الأنيق */}
        <div className="flex items-baseline gap-1.5 pt-1">
          <span className="text-sm font-bold text-black">{money(product.price)} د.ل</span>
          {product.oldPrice && product.oldPrice > product.price && (
            <del className="text-[11px] text-gray-400 line-through">{money(product.oldPrice)} د.ل</del>
          )}
        </div>

        {/* أزرار الإضافة والسلة السفليّة تماماً مثل الصورة */}
        <div className="flex items-center gap-2 pt-1">
          {/* زر المفضلة (القلب) */}
          <button
            onClick={() => toggleFavorite(product.id)}
            className={`p-2 rounded-xl border transition-colors flex items-center justify-center ${
              favorite 
                ? "border-red-500 bg-red-50 text-red-500" 
                : "border-gray-200 text-gray-700 hover:bg-gray-50"
            }`}
            aria-label="المفضلة"
          >
            <Heart className={`w-4 h-4 ${favorite ? "fill-current" : ""}`} />
          </button>

          {/* زر السلة */}
          {product.sizes?.length > 0 || product.colors?.length > 0 ? (
            <Link
              href={`/product/?id=${encodeURIComponent(product.id)}`}
              className="flex-1 bg-black text-white text-xs font-medium py-2 px-3 rounded-xl flex items-center justify-center gap-1.5 hover:bg-gray-800 transition-colors"
            >
              <ShoppingBag className="w-3.5 h-3.5" />
              <span>أضف للسلة</span>
            </Link>
          ) : (
            <button
              onClick={quickAdd}
              disabled={soldOut}
              className="flex-1 bg-black text-white text-xs font-medium py-2 px-3 rounded-xl flex items-center justify-center gap-1.5 hover:bg-gray-800 disabled:bg-gray-300 transition-colors"
            >
              <ShoppingBag className="w-3.5 h-3.5" />
              <span>{soldOut ? "نفد" : "أضف للسلة"}</span>
            </button>
          )}
        </div>
      </div>
    </article>
  );
}
