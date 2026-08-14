"use client";

import { ImageIcon } from "lucide-react";
import { useState } from "react";

export function ProductImage({ src, alt, className = "" }: { src?: string; alt: string; className?: string }) {
  const [failed, setFailed] = useState(!src);
  if (failed) {
    return <div className={`image-fallback ${className}`} role="img" aria-label={alt}><ImageIcon /><span>AVEA</span></div>;
  }
  return <img className={className} src={src} alt={alt} loading="lazy" onError={() => setFailed(true)} />;
}
