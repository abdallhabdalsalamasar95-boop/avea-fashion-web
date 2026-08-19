export function getAppBaseUrl(): string {
  return (process.env.NEXT_PUBLIC_APP_URL ?? "https://avea-fashion-web.onrender.com").replace(/\/+$/, "");
}

export function openMessengerShare(url: string): void {
  const messengerUrl = `fb-messenger://share/?link=${encodeURIComponent(url)}`;
  const fallbackUrl = `https://www.facebook.com/dialog/send?link=${encodeURIComponent(url)}&redirect_uri=${encodeURIComponent(url)}`;

  const anchor = document.createElement("a");
  anchor.href = messengerUrl;
  anchor.rel = "noopener noreferrer";
  anchor.style.display = "none";
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);

  window.setTimeout(() => {
    window.open(fallbackUrl, "_blank", "noopener,noreferrer");
  }, 500);
}

export async function shareWithFallback({ title, text, url }: { title: string; text: string; url: string }): Promise<"native" | "messenger" | "copy"> {
  try {
    if (navigator.share) {
      await navigator.share({ title, text, url });
      return "native";
    }
  } catch (error) {
    const isAbort = error instanceof DOMException && error.name === "AbortError";
    if (isAbort) throw error;
  }

  const isMobile = /android|iphone|ipad|ipod/i.test(window.navigator.userAgent);
  if (isMobile) {
    openMessengerShare(url);
    return "messenger";
  }

  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(url);
  }

  return "copy";
}
