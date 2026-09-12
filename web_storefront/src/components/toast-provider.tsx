"use client";

import { Check, Info, Sparkles, X } from "lucide-react";
import React, { createContext, useContext, useState, useCallback } from "react";

interface Toast {
  id: string;
  message: string;
  type?: "success" | "info";
}

interface ToastContextType {
  showToast: (message: string, type?: "success" | "info") => void;
}

const ToastContext = createContext<ToastContextType | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const showToast = useCallback((message: string, type: "success" | "info" = "success") => {
    const id = Math.random().toString(36).substring(2, 9);
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 2800);
  }, []);

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      <div className="luxury-toast-container" aria-live="polite">
        {toasts.map((toast) => (
          <div key={toast.id} className={`luxury-toast-item ${toast.type || "success"}`}>
            <span className="toast-icon">
              {toast.type === "info" ? <Info /> : <Check />}
            </span>
            <span className="toast-text">{toast.message}</span>
            <button
              type="button"
              className="toast-close"
              onClick={() => removeToast(toast.id)}
              aria-label="إغلاق"
            >
              <X />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    return {
      showToast: (msg: string) => {
        if (typeof window !== "undefined") {
          console.log(msg);
        }
      },
    };
  }
  return ctx;
}
