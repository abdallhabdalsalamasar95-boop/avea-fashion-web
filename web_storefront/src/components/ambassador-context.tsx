"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { useAuth } from "@/components/auth-provider";
import { AMBASSADOR_PROFILE_UPDATED_EVENT, getAmbassadorProfile } from "@/lib/ambassador-profile";
import { fetchAppContent } from "@/lib/api";
import { CommissionConfig, defaultCommissionConfig } from "@/lib/commission";
import { AmbassadorProfile } from "@/lib/types";

type AmbassadorContextValue = {
  ambassador: AmbassadorProfile | null;
  loading: boolean;
  commission: CommissionConfig;
};

const AmbassadorContext = createContext<AmbassadorContextValue | null>(null);

export function AmbassadorProvider({ children }: { children: React.ReactNode }) {
  const { user, loading: authLoading } = useAuth();
  const [ambassador, setAmbassador] = useState<AmbassadorProfile | null>(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [commission, setCommission] = useState<CommissionConfig>(defaultCommissionConfig);

  useEffect(() => {
    const controller = new AbortController();
    fetchAppContent(controller.signal)
      .then((content) => setCommission({
        defaultPercent: content.commission?.defaultPercent ?? defaultCommissionConfig.defaultPercent,
        perProductEnabled: content.commission?.perProductEnabled !== false,
      }))
      .catch(() => undefined);
    return () => controller.abort();
  }, []);

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      setAmbassador(null);
      setProfileLoading(false);
      return;
    }

    let active = true;
    setProfileLoading(true);
    getAmbassadorProfile(user)
      .then((profile) => { if (active) setAmbassador(profile); })
      .catch(() => { if (active) setAmbassador(null); })
      .finally(() => { if (active) setProfileLoading(false); });
    return () => { active = false; };
  }, [authLoading, user]);

  useEffect(() => {
    const updateProfile = (event: Event) => {
      const profile = (event as CustomEvent<AmbassadorProfile>).detail;
      if (profile?.uid === user?.uid && profile.status === "active") setAmbassador(profile);
    };
    window.addEventListener(AMBASSADOR_PROFILE_UPDATED_EVENT, updateProfile);
    return () => window.removeEventListener(AMBASSADOR_PROFILE_UPDATED_EVENT, updateProfile);
  }, [user?.uid]);

  const value = useMemo(() => ({
    ambassador,
    loading: authLoading || profileLoading,
    commission,
  }), [ambassador, authLoading, commission, profileLoading]);

  return <AmbassadorContext.Provider value={value}>{children}</AmbassadorContext.Provider>;
}

export function useAmbassador() {
  const value = useContext(AmbassadorContext);
  if (!value) throw new Error("useAmbassador must be used inside AmbassadorProvider");
  return value;
}
