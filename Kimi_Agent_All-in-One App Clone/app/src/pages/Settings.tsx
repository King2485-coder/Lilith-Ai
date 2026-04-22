import { useApp } from '@/store/AppContext';
import type { SettingsTab } from '@/types';
import {
  Smartphone, Radio, Monitor, Battery,
  Bluetooth, Wifi, Globe, Shield, Info
} from 'lucide-react';
import { Switch } from '@/components/ui/switch';

const settingsCategories: { id: SettingsTab; icon: typeof Smartphone; label: string }[] = [
  { id: 'device', icon: Smartphone, label: 'Device' },
  { id: 'channels', icon: Radio, label: 'Channels' },
  { id: 'radio', icon: Radio, label: 'Radio' },
  { id: 'display', icon: Monitor, label: 'Display' },
  { id: 'power', icon: Battery, label: 'Power' },
  { id: 'bluetooth', icon: Bluetooth, label: 'Bluetooth' },
  { id: 'wifi', icon: Wifi, label: 'WiFi' },
  { id: 'mqtt', icon: Globe, label: 'MQTT' },
  { id: 'security', icon: Shield, label: 'Security' },
  { id: 'about', icon: Info, label: 'About' },
];

function DeviceSettings() {
  return (
    <div className="flex flex-col gap-5 max-w-lg">
      <div>
        <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 10 }}>Device Info</h3>
        <div className="panel">
          {[
            { label: 'Node ID', value: '!a1b2c3d4', mono: true },
            { label: 'Firmware Version', value: '2.3.13.8113c49' },
            { label: 'Hardware Model', value: 'T-Beam 1.2' },
          ].map((item, i, arr) => (
            <div
              key={item.label}
              className="flex items-center justify-between py-2.5 px-3"
              style={{ borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}
            >
              <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{item.label}</span>
              <span className={item.mono ? 'font-mono-tech' : ''} style={{ fontSize: 12, color: 'var(--text-primary)' }}>
                {item.value}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div>
        <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 10 }}>User</h3>
        <div className="panel">
          <div className="flex flex-col gap-3 p-3">
            <div className="flex flex-col gap-1">
              <label style={{ fontSize: 11, color: 'var(--text-muted)' }}>Long Name</label>
              <input type="text" defaultValue="Basecamp" className="input-field" />
            </div>
            <div className="flex flex-col gap-1">
              <label style={{ fontSize: 11, color: 'var(--text-muted)' }}>Short Name</label>
              <input type="text" defaultValue="BASE" maxLength={4} className="input-field font-mono-tech" />
            </div>
          </div>
        </div>
      </div>

      <div>
        <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 10 }}>Configuration</h3>
        <div className="panel">
          <div className="flex flex-col">
            {[
              { label: 'Device Role', value: 'CLIENT', options: ['CLIENT', 'CLIENT_MUTE', 'ROUTER', 'REPEATER'] },
              { label: 'Region', value: 'US', options: ['US', 'EU_868', 'EU_433', 'ANZ', 'CN', 'JP'] },
              { label: 'Preset', value: 'LongFast', options: ['LongFast', 'MediumFast', 'ShortFast', 'LongModerate'] },
            ].map((item, i, arr) => (
              <div
                key={item.label}
                className="flex items-center justify-between py-2.5 px-3"
                style={{ borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}
              >
                <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{item.label}</span>
                <select
                  className="input-field"
                  defaultValue={item.value}
                  style={{ fontSize: 12, padding: '3px 8px', minWidth: 140 }}
                >
                  {item.options.map(v => <option key={v} value={v}>{v}</option>)}
                </select>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function ChannelSettings() {
  const { state } = useApp();
  return (
    <div className="flex flex-col gap-3 max-w-lg">
      <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>Channels</h3>
      {state.channels.map((ch) => (
        <div
          key={ch.id}
          className="panel"
          style={{ padding: '10px 12px' }}
        >
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>{ch.name}</span>
              {ch.encrypted && (
                <span
                  className="font-mono-tech"
                  style={{ fontSize: 9, padding: '1px 6px', borderRadius: 4, backgroundColor: 'var(--accent-dim)', color: 'var(--accent)' }}
                >
                  ENCRYPTED
                </span>
              )}
            </div>
            <span className="badge">{ch.preset}</span>
          </div>
          <div className="grid grid-cols-3 gap-2 font-mono-tech">
            <div>
              <span className="text-xs-muted">Freq</span>
              <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{ch.frequency} MHz</div>
            </div>
            <div>
              <span className="text-xs-muted">SF</span>
              <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{ch.sf}</div>
            </div>
            <div>
              <span className="text-xs-muted">BW</span>
              <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{ch.bandwidth}k</div>
            </div>
          </div>
        </div>
      ))}
      <button className="btn-secondary self-start" style={{ fontSize: 12 }}>
        + Add Channel
      </button>
    </div>
  );
}

function RadioSettings() {
  return (
    <div className="flex flex-col gap-5 max-w-lg">
      <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>Radio Configuration</h3>
      <div className="panel">
        {[
          { label: 'Frequency Offset', value: '0.0', unit: 'MHz' },
          { label: 'Transmit Power', value: '17', unit: 'dBm' },
          { label: 'Spreading Factor', value: '11', unit: '' },
          { label: 'Coding Rate', value: '4/5', unit: '' },
          { label: 'Bandwidth', value: '250', unit: 'kHz' },
          { label: 'Hop Limit', value: '3', unit: '' },
        ].map((item, i, arr) => (
          <div
            key={item.label}
            className="flex items-center justify-between py-2.5 px-3"
            style={{ borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}
          >
            <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{item.label}</span>
            <div className="flex items-center gap-1">
              <input
                type="text"
                defaultValue={item.value}
                className="input-field font-mono-tech text-right"
                style={{ width: 80, fontSize: 12, padding: '3px 8px' }}
              />
              {item.unit && <span className="text-xs-muted">{item.unit}</span>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function GenericSettings({ title, items }: { title: string; items: { label: string; type: 'toggle' | 'text' | 'select'; value?: string; options?: string[] }[] }) {
  return (
    <div className="flex flex-col gap-5 max-w-lg">
      <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>{title}</h3>
      <div className="panel">
        {items.map((item, i, arr) => (
          <div
            key={item.label}
            className="flex items-center justify-between py-2.5 px-3"
            style={{ borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}
          >
            <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{item.label}</span>
            {item.type === 'toggle' && <Switch defaultChecked />}
            {item.type === 'text' && (
              <input type="text" defaultValue={item.value} className="input-field font-mono-tech" style={{ width: 160, fontSize: 12, padding: '3px 8px' }} />
            )}
            {item.type === 'select' && (
              <select className="input-field" style={{ fontSize: 12, padding: '3px 8px', minWidth: 140 }}>
                {item.options?.map(o => <option key={o} value={o}>{o}</option>)}
              </select>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function AboutSettings() {
  return (
    <div className="flex flex-col gap-5 max-w-lg">
      <h3 style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>About</h3>
      <div className="panel p-4">
        <div className="flex flex-col items-center gap-2 mb-4">
          <div
            className="flex items-center justify-center"
            style={{
              width: 48,
              height: 48,
              borderRadius: 12,
              backgroundColor: 'var(--accent-dim)',
            }}
          >
            <RadioIcon size={24} style={{ color: 'var(--accent)' }} />
          </div>
          <span style={{ fontSize: 16, fontWeight: 600, color: 'var(--text-primary)' }}>MeshCom</span>
          <span className="text-xs-muted">v1.0.0</span>
        </div>
        <p style={{ fontSize: 12, color: 'var(--text-secondary)', lineHeight: 1.6, textAlign: 'center' }}>
          MeshCom is a web-based mesh network communicator for Meshtastic-compatible devices.
          Built for off-grid communication, emergency preparedness, and outdoor adventures.
        </p>
      </div>
    </div>
  );
}

function RadioIcon({ size, style }: { size?: number; style?: React.CSSProperties }) {
  return (
    <svg width={size || 16} height={size || 16} viewBox="0 0 24 24" fill="none" stroke={style?.color || 'currentColor'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="5" r="2" />
      <path d="M10 10l2-5 2 5" />
      <path d="M8 15l4-10 4 10" />
      <path d="M4 20l8-15 8 15" />
      <line x1="2" y1="20" x2="22" y2="20" />
    </svg>
  );
}

export function Settings() {
  const { state, setSettingsTab } = useApp();

  const renderSettings = () => {
    switch (state.settingsTab) {
      case 'device': return <DeviceSettings />;
      case 'channels': return <ChannelSettings />;
      case 'radio': return <RadioSettings />;
      case 'display':
        return <GenericSettings title="Display" items={[
          { label: 'Screen Timeout', type: 'select', value: '60', options: ['15', '30', '60', '120', '300', 'Never'] },
          { label: 'Brightness', type: 'select', value: '100', options: ['25', '50', '75', '100'] },
          { label: 'GPS Format', type: 'select', value: 'DEC', options: ['DEC', 'DMS', 'UTM'] },
          { label: 'Show FPS', type: 'toggle' },
        ]} />;
      case 'power':
        return <GenericSettings title="Power" items={[
          { label: 'Battery Saving Mode', type: 'toggle' },
          { label: 'Shutdown on Low Battery', type: 'toggle' },
          { label: 'ADC Multiplier', type: 'text', value: '2.0' },
          { label: 'Min Wake Time', type: 'text', value: '10' },
        ]} />;
      case 'bluetooth':
        return <GenericSettings title="Bluetooth" items={[
          { label: 'Enabled', type: 'toggle' },
          { label: 'Pairing Mode', type: 'toggle' },
          { label: 'Fixed PIN', type: 'text', value: '123456' },
        ]} />;
      case 'wifi':
        return <GenericSettings title="WiFi" items={[
          { label: 'Enabled', type: 'toggle' },
          { label: 'SSID', type: 'text', value: 'MyNetwork' },
          { label: 'Password', type: 'text', value: '********' },
        ]} />;
      case 'mqtt':
        return <GenericSettings title="MQTT" items={[
          { label: 'Enabled', type: 'toggle' },
          { label: 'Server', type: 'text', value: 'mqtt.meshtastic.org' },
          { label: 'Username', type: 'text', value: 'mesh' },
          { label: 'Encryption', type: 'toggle' },
        ]} />;
      case 'security':
        return <GenericSettings title="Security" items={[
          { label: 'Public Key', type: 'text', value: 'AQ==' },
          { label: 'Private Key', type: 'text', value: '********' },
          { label: 'Admin Key', type: 'text', value: '********' },
          { label: 'Managed Mode', type: 'toggle' },
        ]} />;
      case 'about': return <AboutSettings />;
      default: return <DeviceSettings />;
    }
  };

  return (
    <div className="flex h-full">
      {/* Detail Panel - Settings Categories */}
      <div
        className="flex flex-col flex-shrink-0 h-full"
        style={{
          width: 220,
          backgroundColor: 'var(--bg-surface)',
          borderRight: '1px solid var(--border-subtle)',
        }}
      >
        <div className="p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-primary)' }}>Settings</span>
        </div>
        <div className="flex flex-col py-1">
          {settingsCategories.map((cat) => {
            const Icon = cat.icon;
            const isActive = state.settingsTab === cat.id;
            return (
              <button
                key={cat.id}
                onClick={() => setSettingsTab(cat.id)}
                className="flex items-center gap-2.5 px-3 py-2 text-left transition-colors"
                style={{
                  backgroundColor: isActive ? 'var(--accent-dim)' : 'transparent',
                  borderLeft: isActive ? '3px solid var(--accent)' : '3px solid transparent',
                  color: isActive ? 'var(--accent)' : 'var(--text-secondary)',
                }}
              >
                <Icon size={15} strokeWidth={isActive ? 2 : 1.5} />
                <span style={{ fontSize: 12, fontWeight: isActive ? 500 : 400 }}>{cat.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Content Area */}
      <div className="flex-1 overflow-y-auto p-5" style={{ backgroundColor: 'var(--bg-base)' }}>
        {renderSettings()}
      </div>
    </div>
  );
}
