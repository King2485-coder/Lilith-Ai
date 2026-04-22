import React, { createContext, useContext, useEffect, useMemo, useState } from "react";

import { LilithScreenKey } from "../constants/lilith-ui";

type CommandActionLog = {
  id: string;
  command: string;
  status: "success" | "error" | "blocked";
  detail: string;
  createdAt: string;
  trace_id?: string;
  operation_id?: string;
};

type CommandContextValue = {
  activeScreen: LilithScreenKey;
  setActiveScreen: (screen: LilithScreenKey) => void;
  activeConversationUserId: string;
  setActiveConversationUserId: (userId: string) => void;
  activeBrowserUrl: string;
  setActiveBrowserUrl: (url: string) => void;
  activeSelectedContent: string;
  setActiveSelectedContent: (content: string) => void;
  preferredCurrency: string;
  setPreferredCurrency: (currency: string) => void;
  chatParticipants: string[];
  setChatParticipants: (participants: string[]) => void;
  vaultLocked: boolean;
  vaultLockUntil: number;
  unlockVault: (unlockMs?: number) => void;
  lockVault: () => void;
  recentActions: CommandActionLog[];
  pushAction: (action: Omit<CommandActionLog, "id" | "createdAt">) => void;
};

const CommandContext = createContext<CommandContextValue | undefined>(undefined);

export function CommandContextProvider({ children }: { children: React.ReactNode }) {
  const [activeScreen, setActiveScreen] = useState<LilithScreenKey>("home");
  const [activeConversationUserId, setActiveConversationUserId] = useState("");
  const [activeBrowserUrl, setActiveBrowserUrl] = useState("");
  const [activeSelectedContent, setActiveSelectedContent] = useState("");
  const [preferredCurrency, setPreferredCurrency] = useState("USD");
  const [chatParticipants, setChatParticipants] = useState<string[]>([]);
  const [vaultLocked, setVaultLocked] = useState(true);
  const [vaultLockUntil, setVaultLockUntil] = useState(0);
  const [recentActions, setRecentActions] = useState<CommandActionLog[]>([]);

  const pushAction = (action: Omit<CommandActionLog, "id" | "createdAt">) => {
    setRecentActions((prev) => [
      {
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        createdAt: new Date().toISOString(),
        ...action,
      },
      ...prev,
    ].slice(0, 20));
  };

  const unlockVault = (unlockMs = 5 * 60 * 1000) => {
    const until = Date.now() + unlockMs;
    setVaultLocked(false);
    setVaultLockUntil(until);
  };

  const lockVault = () => {
    setVaultLocked(true);
    setVaultLockUntil(0);
  };

  useEffect(() => {
    const timer = setInterval(() => {
      if (!vaultLocked && vaultLockUntil > 0 && Date.now() >= vaultLockUntil) {
        setVaultLocked(true);
        setVaultLockUntil(0);
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [vaultLocked, vaultLockUntil]);

  const value = useMemo<CommandContextValue>(
    () => ({
      activeScreen,
      setActiveScreen,
      activeConversationUserId,
      setActiveConversationUserId,
      activeBrowserUrl,
      setActiveBrowserUrl,
      activeSelectedContent,
      setActiveSelectedContent,
      preferredCurrency,
      setPreferredCurrency,
      chatParticipants,
      setChatParticipants,
      vaultLocked,
      vaultLockUntil,
      unlockVault,
      lockVault,
      recentActions,
      pushAction,
    }),
    [
      activeScreen,
      activeConversationUserId,
      activeBrowserUrl,
      activeSelectedContent,
      preferredCurrency,
      chatParticipants,
      vaultLocked,
      vaultLockUntil,
      recentActions,
    ]
  );

  return <CommandContext.Provider value={value}>{children}</CommandContext.Provider>;
}

export function useCommandContext() {
  const value = useContext(CommandContext);
  if (!value) throw new Error("useCommandContext must be used inside CommandContextProvider");
  return value;
}
