import React from "react";
import { Stack } from "expo-router";

import { SessionProvider } from "../providers/SessionProvider";
import { CommandContextProvider } from "../providers/CommandContextProvider";
import { BrowserProvider } from "../providers/BrowserProvider";

export default function RootLayout() {
  return (
    <SessionProvider>
      <CommandContextProvider>
        <BrowserProvider>
          <Stack screenOptions={{ headerShown: false }} />
        </BrowserProvider>
      </CommandContextProvider>
    </SessionProvider>
  );
}
