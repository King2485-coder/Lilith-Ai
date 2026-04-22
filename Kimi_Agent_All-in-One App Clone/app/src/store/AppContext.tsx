import React, { createContext, useContext, useState, useCallback } from 'react';
import type { AppState, AppContextType, ConnectionType, Toast, SettingsTab } from '@/types';

const initialNodes = [
  { id: '!a1b2c3', longName: 'Basecamp', shortName: 'BASE', battery: 87, rssi: -45, hops: 0, online: true, lat: 37.7749, lon: -122.4194, lastSeen: 'now' },
  { id: '!7c1a45', longName: 'Ridge North', shortName: 'RIDN', battery: 62, rssi: -68, hops: 1, online: true, lat: 37.7850, lon: -122.4100, lastSeen: '2 min ago' },
  { id: '!a3f267', longName: 'Summit One', shortName: 'SUM1', battery: 23, rssi: -72, hops: 2, online: true, lat: 37.7900, lon: -122.4050, lastSeen: '5 min ago' },
  { id: '!9b4c89', longName: 'Trail South', shortName: 'TRLS', battery: 91, rssi: -52, hops: 1, online: true, lat: 37.7680, lon: -122.4300, lastSeen: '1 min ago' },
  { id: '!d8e101', longName: 'Valley East', shortName: 'VLYE', battery: 45, rssi: -85, hops: 2, online: true, lat: 37.7800, lon: -122.4000, lastSeen: '8 min ago' },
  { id: '!e5f212', longName: 'Camp West', shortName: 'CMPW', battery: 8, rssi: -92, hops: 3, online: false, lat: 37.7720, lon: -122.4350, lastSeen: '2 hours ago' },
  { id: '!c6g323', longName: 'Point Echo', shortName: 'PECH', battery: 78, rssi: -58, hops: 1, online: true, lat: 37.7880, lon: -122.4250, lastSeen: '3 min ago' },
  { id: '!h7i434', longName: 'Node Foxtrot', shortName: 'FOX', battery: 34, rssi: -78, hops: 2, online: false, lat: 37.7750, lon: -122.3950, lastSeen: '45 min ago' },
];

const initialChannels = [
  { id: 'ch0', name: 'LongFast', preset: 'Long Fast', frequency: '906.875', sf: 11, bandwidth: 250, encrypted: false, unread: 2 },
  { id: 'ch1', name: 'MediumFast', preset: 'Medium Fast', frequency: '906.875', sf: 9, bandwidth: 250, encrypted: true, unread: 0 },
  { id: 'ch2', name: 'ShortFast', preset: 'Short Fast', frequency: '906.875', sf: 7, bandwidth: 250, encrypted: true, unread: 0 },
  { id: 'ch3', name: 'Admin', preset: 'Long Moderate', frequency: '906.875', sf: 11, bandwidth: 125, encrypted: true, unread: 0 },
];

const initialMessages: Record<string, any[]> = {
  ch0: [
    { id: 'm1', senderId: '!7c1a45', senderName: 'Ridge North', content: 'Anyone heading to the ridge today? Weather looks clear.', timestamp: '10:23 AM', isSelf: false },
    { id: 'm2', senderId: '!a3f267', senderName: 'Summit One', content: 'Copy basecamp, heading up in 20min. Will report from checkpoint 3.', timestamp: '10:25 AM', isSelf: false },
    { id: 'm3', senderId: '!9b4c89', senderName: 'Trail South', content: "I'm at the water crossing \u2014 water level is low, safe to pass.", timestamp: '10:31 AM', isSelf: false },
    { id: 'm4', senderId: '!7c1a45', senderName: 'Ridge North', content: 'Good to know, thanks trailS. All teams check in every 30min please.', timestamp: '10:33 AM', isSelf: false },
    { id: 'm5', senderId: '!d8e101', senderName: 'Valley East', content: 'Ridge north reporting. No movement detected. All clear.', timestamp: '10:45 AM', isSelf: false },
  ],
};

const initialDMThreads: Record<string, any> = {
  '!a3f267': {
    nodeId: '!a3f267',
    nodeName: 'Summit One',
    nodeShortName: 'SUM1',
    online: true,
    unread: 1,
    messages: [
      { id: 'dm1', senderId: '!a3f267', senderName: 'Summit One', content: 'Hey, my battery is at 15%. Bringing spare?', timestamp: '10:28 AM', isSelf: false },
      { id: 'dm2', senderId: 'self', senderName: 'You', content: "Yeah, have an extra 18650. I'll leave it at checkpoint 2.", timestamp: '10:29 AM', isSelf: true },
      { id: 'dm3', senderId: '!a3f267', senderName: 'Summit One', content: 'Perfect, thanks!', timestamp: '10:29 AM', isSelf: false },
    ],
  },
  '!9b4c89': {
    nodeId: '!9b4c89',
    nodeName: 'Trail South',
    nodeShortName: 'TRLS',
    online: true,
    unread: 0,
    messages: [
      { id: 'dm4', senderId: '!9b4c89', senderName: 'Trail South', content: 'Found a good campsite near mile 4. Flat ground with tree cover.', timestamp: 'Yesterday', isSelf: false },
    ],
  },
};

const initialState: AppState = {
  connection: { type: null, status: 'disconnected', deviceName: null },
  nodes: initialNodes,
  channels: initialChannels,
  messages: initialMessages,
  dmThreads: initialDMThreads,
  selectedChannelId: 'ch0',
  selectedDMNodeId: null,
  viewMode: 'channels',
  settingsTab: 'device',
  toasts: [],
};

const AppContext = createContext<AppContextType | null>(null);

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AppState>(initialState);

  const addToast = useCallback((toast: Omit<Toast, 'id'>) => {
    const id = Math.random().toString(36).slice(2);
    setState(prev => ({ ...prev, toasts: [...prev.toasts, { ...toast, id }] }));
    setTimeout(() => {
      setState(prev => ({ ...prev, toasts: prev.toasts.filter(t => t.id !== id) }));
    }, toast.duration || 4000);
  }, []);

  const removeToast = useCallback((id: string) => {
    setState(prev => ({ ...prev, toasts: prev.toasts.filter(t => t.id !== id) }));
  }, []);

  const connect = useCallback((type: ConnectionType, deviceName?: string) => {
    setState(prev => ({
      ...prev,
      connection: { type, status: 'connecting', deviceName: deviceName || null },
    }));
    setTimeout(() => {
      setState(prev => ({
        ...prev,
        connection: { type, status: 'connected', deviceName: deviceName || 'Mesh Device' },
      }));
      addToast({ message: `Connected to ${deviceName || 'Mesh Device'}`, type: 'success' });
    }, 1500);
  }, [addToast]);

  const disconnect = useCallback(() => {
    setState(prev => ({
      ...prev,
      connection: { type: null, status: 'disconnected', deviceName: null },
    }));
    addToast({ message: 'Disconnected', type: 'info' });
  }, [addToast]);

  const sendMessage = useCallback((content: string) => {
    const newMsg = {
      id: Math.random().toString(36).slice(2),
      senderId: 'self',
      senderName: 'You',
      content,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      isSelf: true,
    };
    setState(prev => {
      if (prev.viewMode === 'dms' && prev.selectedDMNodeId) {
        const thread = prev.dmThreads[prev.selectedDMNodeId];
        if (!thread) return prev;
        return {
          ...prev,
          dmThreads: {
            ...prev.dmThreads,
            [prev.selectedDMNodeId]: {
              ...thread,
              messages: [...thread.messages, newMsg],
            },
          },
        };
      } else {
        const chMsgs = prev.messages[prev.selectedChannelId] || [];
        return {
          ...prev,
          messages: {
            ...prev.messages,
            [prev.selectedChannelId]: [...chMsgs, newMsg],
          },
        };
      }
    });
  }, []);

  const selectChannel = useCallback((channelId: string) => {
    setState(prev => ({
      ...prev,
      selectedChannelId: channelId,
      selectedDMNodeId: null,
      viewMode: 'channels',
      channels: prev.channels.map(ch => ch.id === channelId ? { ...ch, unread: 0 } : ch),
    }));
  }, []);

  const selectDM = useCallback((nodeId: string | null) => {
    setState(prev => {
      if (!nodeId) return { ...prev, selectedDMNodeId: null, viewMode: 'channels' };
      const updatedThreads = { ...prev.dmThreads };
      if (updatedThreads[nodeId]) {
        updatedThreads[nodeId] = { ...updatedThreads[nodeId], unread: 0 };
      }
      return {
        ...prev,
        selectedDMNodeId: nodeId,
        selectedChannelId: '',
        viewMode: 'dms',
        dmThreads: updatedThreads,
      };
    });
  }, []);

  const setViewMode = useCallback((mode: 'channels' | 'dms') => {
    setState(prev => ({ ...prev, viewMode: mode }));
  }, []);

  const setSettingsTab = useCallback((tab: SettingsTab) => {
    setState(prev => ({ ...prev, settingsTab: tab }));
  }, []);

  return (
    <AppContext.Provider value={{
      state, setState, connect, disconnect, sendMessage,
      selectChannel, selectDM, setViewMode, setSettingsTab,
      addToast, removeToast,
    }}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp must be used within AppProvider');
  return ctx;
}
