import { useState } from 'react';
import { useApp } from '@/store/AppContext';
import {
  Search, Battery, BatteryMedium, BatteryLow, BatteryWarning,
  LayoutGrid, List, ArrowUpDown
} from 'lucide-react';

function SignalBars({ rssi }: { rssi: number }) {
  const bars = rssi > -60 ? 4 : rssi > -70 ? 3 : rssi > -80 ? 2 : 1;
  const color = rssi > -60 ? 'var(--signal-good)' : rssi > -75 ? 'var(--signal-mid)' : 'var(--signal-weak)';

  return (
    <div className="flex items-end gap-0.5" style={{ height: 12 }}>
      {[1, 2, 3, 4].map((i) => (
        <div
          key={i}
          style={{
            width: 3,
            height: i * 3,
            borderRadius: 1,
            backgroundColor: i <= bars ? color : 'var(--border-default)',
            transition: 'all 150ms ease',
          }}
        />
      ))}
    </div>
  );
}

function BatteryIcon({ level }: { level: number }) {
  const color = level > 50 ? 'var(--accent)' : level > 20 ? 'var(--warning)' : 'var(--danger)';
  return (
    <div className="flex items-center gap-1">
      {level > 50 ? <Battery size={14} style={{ color }} /> :
       level > 20 ? <BatteryMedium size={14} style={{ color }} /> :
       level > 10 ? <BatteryLow size={14} style={{ color }} /> :
       <BatteryWarning size={14} style={{ color }} />}
      <span className="font-mono-tech" style={{ fontSize: 11, color }}>{level}%</span>
    </div>
  );
}

export function Nodes() {
  const { state } = useApp();
  const [filter, setFilter] = useState('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'online' | 'offline'>('all');
  const [viewMode, setViewMode] = useState<'grid' | 'table'>('grid');
  const [sortField, setSortField] = useState<string>('longName');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc');

  const filteredNodes = state.nodes
    .filter(n => {
      const matchesFilter = !filter ||
        n.longName.toLowerCase().includes(filter.toLowerCase()) ||
        n.shortName.toLowerCase().includes(filter.toLowerCase()) ||
        n.id.toLowerCase().includes(filter.toLowerCase());
      const matchesStatus = activeFilter === 'all' ||
        (activeFilter === 'online' && n.online) ||
        (activeFilter === 'offline' && !n.online);
      return matchesFilter && matchesStatus;
    })
    .sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1;
      if (sortField === 'longName') return a.longName.localeCompare(b.longName) * dir;
      if (sortField === 'battery') return (a.battery - b.battery) * dir;
      if (sortField === 'rssi') return (a.rssi - b.rssi) * dir;
      return 0;
    });

  const totalNodes = state.nodes.length;
  const onlineNodes = state.nodes.filter(n => n.online).length;
  const offlineNodes = state.nodes.filter(n => !n.online).length;

  const handleSort = (field: string) => {
    if (sortField === field) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDir('asc');
    }
  };

  return (
    <div className="flex h-full">
      {/* Detail Panel */}
      <div
        className="flex flex-col flex-shrink-0 h-full"
        style={{
          width: 280,
          backgroundColor: 'var(--bg-surface)',
          borderRight: '1px solid var(--border-subtle)',
        }}
      >
        {/* Search */}
        <div className="p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          <div className="relative">
            <Search size={14} className="absolute" style={{ left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
            <input
              type="text"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              placeholder="Filter nodes..."
              className="input-field w-full"
              style={{ paddingLeft: 30, fontSize: 12 }}
            />
          </div>
        </div>

        {/* Filter Pills */}
        <div className="flex gap-1.5 p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          {(['all', 'online', 'offline'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setActiveFilter(f)}
              className="btn-ghost capitalize"
              style={{
                fontSize: 11,
                padding: '3px 10px',
                backgroundColor: activeFilter === f ? 'var(--accent-dim)' : 'transparent',
                color: activeFilter === f ? 'var(--accent)' : 'var(--text-secondary)',
              }}
            >
              {f}
            </button>
          ))}
        </div>

        {/* Stats */}
        <div className="grid grid-cols-3 gap-2 p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          {[
            { label: 'Nodes', value: totalNodes, color: 'var(--text-primary)' },
            { label: 'Online', value: onlineNodes, color: 'var(--accent)' },
            { label: 'Offline', value: offlineNodes, color: 'var(--text-muted)' },
          ].map((stat) => (
            <div
              key={stat.label}
              className="flex flex-col items-center py-2"
              style={{
                backgroundColor: 'var(--bg-elevated)',
                borderRadius: 6,
                border: '1px solid var(--border-subtle)',
              }}
            >
              <span style={{ fontSize: 18, fontWeight: 700, color: stat.color }}>{stat.value}</span>
              <span className="text-xs-muted">{stat.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Content Area */}
      <div className="flex flex-col flex-1 h-full overflow-hidden" style={{ backgroundColor: 'var(--bg-base)' }}>
        {/* Header */}
        <div
          className="flex items-center justify-between px-4"
          style={{
            height: 48,
            borderBottom: '1px solid var(--border-subtle)',
            backgroundColor: 'var(--bg-surface)',
          }}
        >
          <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-primary)' }}>
            Nodes ({filteredNodes.length})
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setViewMode('grid')}
              className={`icon-btn ${viewMode === 'grid' ? 'active' : ''}`}
              title="Grid view"
            >
              <LayoutGrid size={16} />
            </button>
            <button
              onClick={() => setViewMode('table')}
              className={`icon-btn ${viewMode === 'table' ? 'active' : ''}`}
              title="Table view"
            >
              <List size={16} />
            </button>
          </div>
        </div>

        {/* Grid View */}
        {viewMode === 'grid' ? (
          <div className="flex-1 overflow-y-auto p-4">
            <div className="grid gap-3" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))' }}>
              {filteredNodes.map((node) => (
                <div
                  key={node.id}
                  className="card-surface transition-all"
                  style={{
                    borderLeft: node.online ? '3px solid var(--accent)' : '3px solid transparent',
                    opacity: node.online ? 1 : 0.7,
                  }}
                >
                  {/* Top Row */}
                  <div className="flex items-center gap-2.5 mb-2">
                    <div
                      className="relative flex items-center justify-center flex-shrink-0"
                      style={{
                        width: 36,
                        height: 36,
                        borderRadius: '50%',
                        backgroundColor: 'var(--bg-elevated)',
                        border: '1px solid var(--border-default)',
                        fontSize: 11,
                        fontWeight: 600,
                        color: 'var(--text-secondary)',
                      }}
                    >
                      {node.shortName.slice(0, 2)}
                      <div
                        style={{
                          position: 'absolute',
                          bottom: 0,
                          right: 0,
                          width: 10,
                          height: 10,
                          borderRadius: '50%',
                          backgroundColor: node.online ? 'var(--accent)' : 'var(--text-muted)',
                          border: '2px solid var(--bg-elevated)',
                        }}
                      />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="truncate" style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>
                          {node.longName}
                        </span>
                        <span
                          className="font-mono-tech flex-shrink-0"
                          style={{
                            fontSize: 10,
                            padding: '1px 6px',
                            borderRadius: 4,
                            backgroundColor: 'var(--accent-dim)',
                            color: 'var(--accent)',
                          }}
                        >
                          {node.shortName}
                        </span>
                      </div>
                      <span className="font-mono-tech text-xs-muted">{node.id}</span>
                    </div>
                  </div>

                  {/* Middle */}
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs-muted">Last seen {node.lastSeen}</span>
                    {node.hops > 0 && (
                      <span
                        className="font-mono-tech"
                        style={{
                          fontSize: 10,
                          padding: '1px 6px',
                          borderRadius: 4,
                          backgroundColor: 'var(--bg-input)',
                          color: 'var(--text-secondary)',
                        }}
                      >
                        {node.hops}h
                      </span>
                    )}
                  </div>

                  {/* Bottom Metrics */}
                  <div className="flex items-center justify-between pt-2" style={{ borderTop: '1px solid var(--border-subtle)' }}>
                    <BatteryIcon level={node.battery} />
                    <div className="flex items-center gap-1.5">
                      <SignalBars rssi={node.rssi} />
                      <span className="font-mono-tech" style={{ fontSize: 10, color: 'var(--text-secondary)' }}>
                        {node.rssi}dBm
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          /* Table View */
          <div className="flex-1 overflow-auto">
            <table className="w-full" style={{ fontSize: 12 }}>
              <thead>
                <tr style={{ backgroundColor: 'var(--bg-surface)', borderBottom: '1px solid var(--border-subtle)' }}>
                  {[
                    { key: 'longName', label: 'Name' },
                    { key: 'id', label: 'ID' },
                    { key: 'lastSeen', label: 'Last Seen' },
                    { key: 'battery', label: 'Battery' },
                    { key: 'rssi', label: 'Signal' },
                    { key: 'hops', label: 'Hops' },
                  ].map((col) => (
                    <th
                      key={col.key}
                      onClick={() => handleSort(col.key)}
                      className="text-left px-3 py-2 font-medium cursor-pointer select-none"
                      style={{ color: 'var(--text-muted)', fontSize: 11 }}
                    >
                      <div className="flex items-center gap-1">
                        {col.label}
                        <ArrowUpDown size={10} style={{ opacity: sortField === col.key ? 1 : 0.4 }} />
                      </div>
                    </th>
                  ))}
                  <th className="text-left px-3 py-2 font-medium" style={{ color: 'var(--text-muted)', fontSize: 11 }}>Position</th>
                </tr>
              </thead>
              <tbody>
                {filteredNodes.map((node) => (
                  <tr
                    key={node.id}
                    className="transition-colors"
                    style={{
                      borderBottom: '1px solid var(--border-subtle)',
                      backgroundColor: node.online ? 'transparent' : 'rgba(0,0,0,0.1)',
                    }}
                    onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = 'var(--bg-elevated)'; }}
                    onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = node.online ? 'transparent' : 'rgba(0,0,0,0.1)'; }}
                  >
                    <td className="px-3 py-2">
                      <div className="flex items-center gap-2">
                        <div
                          style={{
                            width: 8,
                            height: 8,
                            borderRadius: '50%',
                            backgroundColor: node.online ? 'var(--accent)' : 'var(--text-muted)',
                            flexShrink: 0,
                          }}
                        />
                        <span style={{ fontWeight: 500, color: 'var(--text-primary)' }}>{node.longName}</span>
                        <span className="badge font-mono-tech" style={{ fontSize: 9 }}>{node.shortName}</span>
                      </div>
                    </td>
                    <td className="px-3 py-2 font-mono-tech text-xs-muted">{node.id}</td>
                    <td className="px-3 py-2 text-xs-muted">{node.lastSeen}</td>
                    <td className="px-3 py-2">
                      <BatteryIcon level={node.battery} />
                    </td>
                    <td className="px-3 py-2">
                      <div className="flex items-center gap-1.5">
                        <SignalBars rssi={node.rssi} />
                        <span className="font-mono-tech" style={{ fontSize: 10, color: 'var(--text-secondary)' }}>{node.rssi}dBm</span>
                      </div>
                    </td>
                    <td className="px-3 py-2 font-mono-tech" style={{ color: 'var(--text-secondary)' }}>{node.hops}h</td>
                    <td className="px-3 py-2 font-mono-tech text-xs-muted">
                      {node.lat.toFixed(4)}, {node.lon.toFixed(4)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
