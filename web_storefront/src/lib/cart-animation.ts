const CART_TARGET_SELECTOR = "[data-cart-target]";

function visibleCartTarget(): HTMLElement | null {
  const preferred = window.matchMedia("(max-width: 850px)").matches ? "mobile" : "desktop";
  const targets = Array.from(document.querySelectorAll<HTMLElement>(CART_TARGET_SELECTOR));
  return targets.find((target) => target.dataset.cartTarget === preferred && target.getClientRects().length > 0)
    ?? targets.find((target) => target.getClientRects().length > 0)
    ?? null;
}

function celebrateArrival(target: HTMLElement, endX: number, endY: number) {
  target.classList.remove("cart-arrival");
  void target.offsetWidth;
  target.classList.add("cart-arrival");
  window.setTimeout(() => target.classList.remove("cart-arrival"), 650);

  for (let index = 0; index < 4; index += 1) {
    const spark = document.createElement("i");
    spark.className = "cart-flight-spark";
    spark.style.left = `${endX}px`;
    spark.style.top = `${endY}px`;
    spark.style.setProperty("--spark-angle", `${index * 90 - 25}deg`);
    document.body.appendChild(spark);
    spark.addEventListener("animationend", () => spark.remove(), { once: true });
  }
}

export function animateProductToCart(source: HTMLElement) {
  if (typeof window === "undefined") return;
  const target = visibleCartTarget();
  if (!target) return;

  const targetRect = target.getBoundingClientRect();
  const endX = targetRect.left + targetRect.width / 2;
  const endY = targetRect.top + targetRect.height / 2;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    celebrateArrival(target, endX, endY);
    return;
  }

  const media = source.closest(".product-media, .gallery")?.querySelector<HTMLImageElement>("img")
    ?? document.querySelector<HTMLImageElement>(".main-image img");
  const sourceRect = media?.getBoundingClientRect() ?? source.getBoundingClientRect();
  const width = Math.max(46, Math.min(82, sourceRect.width * 0.32));
  const height = width * 1.28;
  const startX = sourceRect.left + sourceRect.width / 2 - width / 2;
  const startY = sourceRect.top + sourceRect.height / 2 - height / 2;
  const deltaX = endX - (startX + width / 2);
  const deltaY = endY - (startY + height / 2);
  const lift = Math.max(70, Math.min(150, Math.abs(deltaX) * 0.18));

  const flyer = document.createElement("div");
  flyer.className = "cart-flight-item";
  flyer.setAttribute("aria-hidden", "true");
  flyer.style.left = `${startX}px`;
  flyer.style.top = `${startY}px`;
  flyer.style.width = `${width}px`;
  flyer.style.height = `${height}px`;
  if (media?.currentSrc || media?.src) {
    const image = document.createElement("img");
    image.src = media.currentSrc || media.src;
    image.alt = "";
    flyer.appendChild(image);
  } else {
    flyer.textContent = "👗";
  }
  document.body.appendChild(flyer);

  const animation = flyer.animate([
    { transform: "translate3d(0, 0, 0) rotate(0deg) scale(1)", opacity: 1, offset: 0 },
    { transform: `translate3d(${deltaX * 0.43}px, ${deltaY * 0.43 - lift}px, 0) rotate(-7deg) scale(.82)`, opacity: 1, offset: 0.48 },
    { transform: `translate3d(${deltaX * 0.78}px, ${deltaY * 0.78 - lift * 0.48}px, 0) rotate(5deg) scale(.5)`, opacity: .92, offset: 0.78 },
    { transform: `translate3d(${deltaX}px, ${deltaY}px, 0) rotate(0deg) scale(.12)`, opacity: .15, offset: 1 },
  ], {
    duration: 760,
    easing: "cubic-bezier(.22,.78,.22,1)",
    fill: "forwards",
  });

  animation.addEventListener("finish", () => {
    flyer.remove();
    celebrateArrival(target, endX, endY);
  }, { once: true });
  animation.addEventListener("cancel", () => flyer.remove(), { once: true });
}
