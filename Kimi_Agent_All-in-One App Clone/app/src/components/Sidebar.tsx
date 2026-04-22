import { useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '@/store/AppContext';
import {
  MessageSquare, Users, Map, Share2, Settings,
  Radio, Bluetooth, Wifi, WifiOff
} from 'lucide-react';

const navItems = [
  { path: '/messages', icon: MessageSquare, label: 'Messages' },
  { path: '/nodes', icon: Users, label: 'Nodes' },
  { path: '/map', icon: Map, label: 'Map' },
  { path: '/network', icon: Share2, label: 'Network' },
  { path: '/settings', icon: Settings, label: 'Settings' },
];

export function Sidebar() {
  const location = useLocation();
  const navigate = useNavigate();
  const { state, connect, disconnect } = useApp();

  const currentPath = location.pathname;

  const handleConnect = () => {
    if (state.connection.status === 'disconnected') {
      connect('serial', 'USB-Serial (/dev/ttyUSB0)');
    }
  };

  return (
    <div
      className="flex flex-col items-center py-3 flex-shrink-0"
      style={{
        width: 56,
        backgroundColor: 'var(--bg-surface)',
        borderRight: '1px solid var(--border-subtle)',
      }}
    >
      {/* Logo */}
      <div className="flex items-center justify-center mb-3" style={{ width: 40, height: 40 }}>
        <Radio size={28} style={{ color: 'var(--accent)' }} strokeWidth={1.5} />
      </div>

      {/* Divider */}
      <div style={{ width: 32, height: 1, backgroundColor: 'var(--border-subtle)', marginBottom: 8 }} />

      {/* Nav Items */}
      <div className="flex flex-col items-center" style={{ gap: 8 }}>
        {navItems.map((item) => {
          const isActive = currentPath === item.path || (item.path === '/messages' && currentPath === '/');
          return (
            <button
              key={item.path}
              onClick={() => navigate(item.path)}
              className={`icon-btn ${isActive ? 'active' : ''}`}
              title={item.label}
              style={{
                backgroundColor: isActive ? 'var(--accent-dim)' : 'transparent',
                color: isActive ? 'var(--accent)' : 'var(--text-muted)',
              }}
            >
              <item.icon size={18} strokeWidth={isActive ? 2 : 1.5} />
            </button>
          );
        })}
      </div>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Connection Status */}
      <div
        style={{ width: 32, height: 1, backgroundColor: 'var(--border-subtle)', marginBottom: 10 }}
      />
      <button
        onClick={state.connection.status === 'connected' ? disconnect : handleConnect}
        className="flex flex-col items-center justify-center"
        style={{
          width: 40,
          height: 40,
          borderRadius: 8,
          transition: 'all 100ms ease',
        }}
        title={state.connection.status === 'connected' ? 'Disconnect' : 'Connect'}
      >
        {state.connection.status === 'connected' ? (
          <div className="relative flex items-center justify-center">
            {state.connection.type === 'bluetooth' ? (
              <Bluetooth size={16} style={{ color: 'var(--info)' }} />
            ) : state.connection.type === 'wifi' ? (
              <Wifi size={16} style={{ color: 'var(--accent)' }} />
            ) : (
              <div style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: 'var(--accent)' }} />
            )}
          </div>
        ) : state.connection.status === 'connecting' ? (
          <div
            style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              backgroundColor: 'var(--warning)',
              animation: 'pulse 1s infinite',
            }}
          />
        ) : (
          <WifiOff size={16} style={{ color: 'var(--text-muted)' }} />
        )}
        <span
          style={{
            fontSize: 8,
            marginTop: 2,
            color:
              state.connection.status === 'connected'
                ? 'var(--accent)'
                : state.connection.status === 'connecting'
                ? 'var(--warning)'
                : 'var(--text-muted)',
          }}
        >
          {state.connection.status === 'connected'
            ? 'ON'
            : state.connection.status === 'connecting'
            ? '...'
            : 'OFF'}
        </span>
      </button>

      {/* Profile Avatar */}
      <div
        className="flex items-center justify-center mt-2"
        style={{
          width: 28,
          height: 28,
          borderRadius: '50%',
          backgroundColor: 'var(--bg-elevated)',
          border: '1px solid var(--border-default)',
          fontSize: 10,
          fontWeight: 600,
          color: 'var(--text-secondary)',
        }}
      >
        M
      </div>
    </div>
  );
}
