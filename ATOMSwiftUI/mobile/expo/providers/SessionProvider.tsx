import React, { createContext, useContext, useMemo, useState } from "react";

type SessionContextValue = {
  apiBase: string;
  token: string;
  setToken: (token: string) => void;
  onboardingCompleted: boolean;
  setOnboardingCompleted: (completed: boolean) => void;
  sessionId: string;
};

const SessionContext = createContext<SessionContextValue | undefined>(undefined);

const DEFAULT_API_BASE = "http://127.0.0.1:8000";
const ONBOARDING_KEY = "lilith_onboarding_completed_v1";

export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState("");
  const [sessionId] = useState(() => `sess_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`);
  const [onboardingCompleted, setOnboardingCompletedState] = useState<boolean>(() => {
    try {
      if (typeof window !== "undefined" && window.localStorage) {
        return window.localStorage.getItem(ONBOARDING_KEY) === "1";
      }
    } catch {
      // Fall back to false.
    }
    return false;
  });

  const setOnboardingCompleted = (completed: boolean) => {
    setOnboardingCompletedState(completed);
    try {
      if (typeof window !== "undefined" && window.localStorage) {
        if (completed) window.localStorage.setItem(ONBOARDING_KEY, "1");
        else window.localStorage.removeItem(ONBOARDING_KEY);
      }
    } catch {
      // Non-blocking persistence fallback.
    }
  };

  const value = useMemo<SessionContextValue>(
    () => ({
      apiBase: DEFAULT_API_BASE,
      token,
      setToken,
      onboardingCompleted,
      setOnboardingCompleted,
      sessionId,
    }),
    [token, onboardingCompleted, sessionId]
  );
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession() {
  const value = useContext(SessionContext);
  if (!value) throw new Error("useSession must be used inside SessionProvider");
  return value;
}
