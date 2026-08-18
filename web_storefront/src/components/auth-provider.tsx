"use client";

import { GoogleAuthProvider, User, browserLocalPersistence, createUserWithEmailAndPassword, onAuthStateChanged, sendPasswordResetEmail, setPersistence, signInWithEmailAndPassword, signInWithPopup, signInWithRedirect, signOut } from "firebase/auth";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { auth } from "@/lib/firebase";

const POPUP_UNAVAILABLE = new Set([
  "auth/popup-blocked",
  "auth/popup-closed-by-user",
  "auth/cancelled-popup-request",
  "auth/operation-not-supported-in-this-environment",
  "auth/web-storage-unsupported",
]);

type AuthContextValue = {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  google: () => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    let unsubscribe = () => {};
    void setPersistence(auth, browserLocalPersistence)
      .catch(() => undefined)
      .finally(() => {
        unsubscribe = onAuthStateChanged(auth, (nextUser) => {
          setUser(nextUser);
          setLoading(false);
        });
      });
    return () => unsubscribe();
  }, []);
  const value = useMemo<AuthContextValue>(() => ({
    user, loading,
    login: async (email, password) => { await signInWithEmailAndPassword(auth, email, password); },
    register: async (email, password) => { await createUserWithEmailAndPassword(auth, email, password); },
    google: async () => {
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: "select_account" });
      try {
        await signInWithPopup(auth, provider);
      } catch (reason) {
        const code = (reason as { code?: string }).code ?? "";
        if (!POPUP_UNAVAILABLE.has(code)) throw reason;
        await signInWithRedirect(auth, provider);
      }
    },
    resetPassword: async (email) => { await sendPasswordResetEmail(auth, email); },
    logout: async () => { await signOut(auth); },
  }), [user, loading]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside AuthProvider");
  return value;
}
