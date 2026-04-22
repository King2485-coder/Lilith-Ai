export interface Node {
  id: string;
  longName: string;
  shortName: string;
  battery: number;
  rssi: number;
  hops: number;
  online: boolean;
  lat: number;
  lon: number;
  lastSeen: string; // relative time string
}

export interface Message {
  id: string;
  senderId: string;
  senderName: string;
  content: string;
  timestamp: string;
  isSelf: boolean;
  channelId?: string;
}

export interface Channel {
  id: string;
  name: string;
  preset: string;
  frequency: string;
  sf: number;
  bandwidth: number;
  encrypted: boolean;
  unread: number;
}

export interface DMThread {
  nodeId: string;
  nodeName: string;
  nodeShortName: string;
  online: boolean;
  messages: Message[];
  unread: number;
}

export type ConnectionType = 'serial' | 'bluetooth' | 'wifi' | null;
export type ConnectionStatus = 'connected' | 'disconnected' | 'connecting';

export interface ConnectionState {
  type: ConnectionType;
  status: ConnectionStatus;
  deviceName: string | null;
}

export type SettingsTab = 'device' | 'channels' | 'radio' | 'display' | 'power' | 'bluetooth' | 'wifi' | 'mqtt' | 'security' | 'about';

export interface AppState {
  connection: ConnectionState;
  nodes: Node[];
  channels: Channel[];
  messages: Record<string, Message[]>; // channelId -> messages
  dmThreads: Record<string, DMThread>; // nodeId -> thread
  selectedChannelId: string;
  selectedDMNodeId: string | null;
  viewMode: 'channels' | 'dms';
  settingsTab: SettingsTab;
  toasts: Toast[];
}

export interface Toast {
  id: string;
  message: string;
  type: 'success' | 'warning' | 'error' | 'info';
  duration?: number;
}

export interface AppContextType {
  state: AppState;
  setState: React.Dispatch<React.SetStateAction<AppState>>;
  connect: (type: ConnectionType, deviceName?: string) => void;
  disconnect: () => void;
  sendMessage: (content: string) => void;
  selectChannel: (channelId: string) => void;
  selectDM: (nodeId: string | null) => void;
  setViewMode: (mode: 'channels' | 'dms') => void;
  setSettingsTab: (tab: SettingsTab) => void;
  addToast: (toast: Omit<Toast, 'id'>) => void;
  removeToast: (id: string) => void;
}
