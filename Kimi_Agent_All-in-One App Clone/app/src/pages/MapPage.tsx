import { useState, useRef, useEffect, useCallback } from 'react';
import { useApp } from '@/store/AppContext';
import {
  ZoomIn, ZoomOut, Crosshair
} from 'lucide-react';

// Simple dark map tile using canvas - no API key needed
function MapCanvas({
  nodes,
  selectedNodeId,
  onSelectNode,
  showRange,
  showConnections,
}: {
  nodes: typeof initialNodes;
  selectedNodeId: string | null;
  onSelectNode: (id: string | null) => void;
  showRange: boolean;
  showConnections: boolean;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [isDragging, setIsDragging] = useState(false);
  const dragStart = useRef({ x: 0, y: 0 });

  // Map bounds
  const bounds = {
    minLat: Math.min(...nodes.map(n => n.lat)) - 0.02,
    maxLat: Math.max(...nodes.map(n => n.lat)) + 0.02,
    minLon: Math.min(...nodes.map(n => n.lon)) - 0.02,
    maxLon: Math.max(...nodes.map(n => n.lon)) + 0.02,
  };

  const latToY = useCallback((lat: number, height: number) => {
    return height - ((lat - bounds.minLat) / (bounds.maxLat - bounds.minLat)) * height;
  }, [bounds]);

  const lonToX = useCallback((lon: number, width: number) => {
    return ((lon - bounds.minLon) / (bounds.maxLon - bounds.minLon)) * width;
  }, [bounds]);

  const drawMap = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const w = canvas.width;
    const h = canvas.height;

    // Clear
    ctx.fillStyle = '#0d120c';
    ctx.fillRect(0, 0, w, h);

    // Draw grid lines
    ctx.strokeStyle = '#1a2218';
    ctx.lineWidth = 0.5;
    for (let i = 0; i < 20; i++) {
      const x = (i / 20) * w;
      const y = (i / 20) * h;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    // Draw terrain contours (simplified)
    ctx.strokeStyle = '#152214';
    ctx.lineWidth = 1;
    for (let i = 0; i < 8; i++) {
      ctx.beginPath();
      const baseY = h * 0.2 + (i * h * 0.08);
      for (let x = 0; x < w; x += 5) {
        const y = baseY + Math.sin(x * 0.01 + i) * 15 + Math.sin(x * 0.003) * 30;
        if (x === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }

    const myNode = nodes[0];

    // Draw connections
    if (showConnections) {
      ctx.strokeStyle = 'rgba(74, 222, 69, 0.15)';
      ctx.lineWidth = 1;
      for (let i = 1; i < nodes.length; i++) {
        const node = nodes[i];
        if (!node.online) continue;
        const x1 = lonToX(myNode.lon, w) + offset.x;
        const y1 = latToY(myNode.lat, h) + offset.y;
        const x2 = lonToX(node.lon, w) + offset.x;
        const y2 = latToY(node.lat, h) + offset.y;

        // Only draw if within reasonable range
        const dist = Math.sqrt((x2-x1)**2 + (y2-y1)**2);
        if (dist < w * 0.6) {
          ctx.setLineDash([4, 4]);
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.lineTo(x2, y2);
          ctx.stroke();
          ctx.setLineDash([]);
        }
      }
    }

    // Draw range circles
    if (showRange) {
      for (const node of nodes) {
        if (!node.online) continue;
        const cx = lonToX(node.lon, w) + offset.x;
        const cy = latToY(node.lat, h) + offset.y;
        const radius = 60 * zoom;

        ctx.strokeStyle = 'rgba(74, 222, 69, 0.08)';
        ctx.lineWidth = 1;
        ctx.setLineDash([3, 6]);
        ctx.beginPath();
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }

    // Draw nodes
    for (const node of nodes) {
      const x = lonToX(node.lon, w) + offset.x;
      const y = latToY(node.lat, h) + offset.y;

      const isSelected = selectedNodeId === node.id;
      const isMyNode = node.id === myNode.id;
      const radius = isSelected ? 18 : isMyNode ? 14 : 12;

      // Pulse ring for selected
      if (isSelected) {
        ctx.strokeStyle = 'rgba(74, 222, 69, 0.3)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.arc(x, y, radius + 10, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Node circle
      ctx.fillStyle = node.online ? (isMyNode ? 'var(--accent)' : 'var(--bg-elevated)') : '#2a3328';
      ctx.strokeStyle = node.online ? 'var(--accent)' : 'var(--text-muted)';
      ctx.lineWidth = isMyNode ? 2.5 : 1.5;
      ctx.beginPath();
      ctx.arc(x, y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();

      // Inner dot for my node
      if (isMyNode) {
        ctx.fillStyle = '#0B0F0A';
        ctx.beginPath();
        ctx.arc(x, y, 5, 0, Math.PI * 2);
        ctx.fill();
      }

      // Label
      ctx.fillStyle = node.online ? 'var(--text-primary)' : 'var(--text-muted)';
      ctx.font = `${isSelected ? '600' : '500'} 11px Inter, sans-serif`;
      ctx.textAlign = 'center';
      ctx.fillText(node.shortName, x, y + radius + 16);

      // Full name for selected
      if (isSelected) {
        ctx.fillStyle = 'var(--text-secondary)';
        ctx.font = '10px Inter, sans-serif';
        ctx.fillText(node.longName, x, y + radius + 28);
      }
    }
  }, [nodes, selectedNodeId, offset, zoom, showRange, showConnections, lonToX, latToY]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resize = () => {
      const parent = canvas.parentElement;
      if (!parent) return;
      canvas.width = parent.clientWidth;
      canvas.height = parent.clientHeight;
      drawMap();
    };

    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, [drawMap]);

  useEffect(() => {
    drawMap();
  }, [drawMap]);

  const handleMouseDown = (e: React.MouseEvent) => {
    setIsDragging(true);
    dragStart.current = { x: e.clientX - offset.x, y: e.clientY - offset.y };
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging) return;
    setOffset({ x: e.clientX - dragStart.current.x, y: e.clientY - dragStart.current.y });
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? 0.9 : 1.1;
    setZoom(z => Math.max(0.5, Math.min(4, z * delta)));
  };

  const handleCanvasClick = (e: React.MouseEvent) => {
    if (isDragging) return;
    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const w = canvas.width;
    const h = canvas.height;

    for (const node of nodes) {
      const nx = lonToX(node.lon, w) + offset.x;
      const ny = latToY(node.lat, h) + offset.y;
      const dist = Math.sqrt((clickX - nx) ** 2 + (clickY - ny) ** 2);
      if (dist < 20) {
        onSelectNode(node.id);
        return;
      }
    }
    onSelectNode(null);
  };

  return (
    <canvas
      ref={canvasRef}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      onWheel={handleWheel}
      onClick={handleCanvasClick}
      style={{
        width: '100%',
        height: '100%',
        cursor: isDragging ? 'grabbing' : 'grab',
      }}
    />
  );
}

// Need to import initialNodes type reference
import type { Node } from '@/types';
const initialNodes: Node[] = [
  { id: '!a1b2c3', longName: 'Basecamp', shortName: 'BASE', battery: 87, rssi: -45, hops: 0, online: true, lat: 37.7749, lon: -122.4194, lastSeen: 'now' },
  { id: '!7c1a45', longName: 'Ridge North', shortName: 'RIDN', battery: 62, rssi: -68, hops: 1, online: true, lat: 37.7850, lon: -122.4100, lastSeen: '2 min ago' },
  { id: '!a3f267', longName: 'Summit One', shortName: 'SUM1', battery: 23, rssi: -72, hops: 2, online: true, lat: 37.7900, lon: -122.4050, lastSeen: '5 min ago' },
  { id: '!9b4c89', longName: 'Trail South', shortName: 'TRLS', battery: 91, rssi: -52, hops: 1, online: true, lat: 37.7680, lon: -122.4300, lastSeen: '1 min ago' },
  { id: '!d8e101', longName: 'Valley East', shortName: 'VLYE', battery: 45, rssi: -85, hops: 2, online: true, lat: 37.7800, lon: -122.4000, lastSeen: '8 min ago' },
  { id: '!e5f212', longName: 'Camp West', shortName: 'CMPW', battery: 8, rssi: -92, hops: 3, online: false, lat: 37.7720, lon: -122.4350, lastSeen: '2 hours ago' },
  { id: '!c6g323', longName: 'Point Echo', shortName: 'PECH', battery: 78, rssi: -58, hops: 1, online: true, lat: 37.7880, lon: -122.4250, lastSeen: '3 min ago' },
  { id: '!h7i434', longName: 'Node Foxtrot', shortName: 'FOX', battery: 34, rssi: -78, hops: 2, online: false, lat: 37.7750, lon: -122.3950, lastSeen: '45 min ago' },
];

export function MapPage() {
  const { state } = useApp();
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [showRange, setShowRange] = useState(true);
  const [showConnections, setShowConnections] = useState(true);

  const selectedNode = state.nodes.find(n => n.id === selectedNodeId);

  return (
    <div className="flex h-full relative">
      {/* Map Area */}
      <div className="flex-1 relative" style={{ backgroundColor: '#0d120c' }}>
        <MapCanvas
          nodes={state.nodes}
          selectedNodeId={selectedNodeId}
          onSelectNode={setSelectedNodeId}
          showRange={showRange}
          showConnections={showConnections}
        />

        {/* Floating Controls */}
        <div
          className="absolute flex flex-col"
          style={{ bottom: 16, right: 16, gap: 4 }}
        >
          <button className="icon-btn" style={{ backgroundColor: 'var(--bg-surface)', border: '1px solid var(--border-subtle)' }}>
            <ZoomIn size={16} />
          </button>
          <button className="icon-btn" style={{ backgroundColor: 'var(--bg-surface)', border: '1px solid var(--border-subtle)' }}>
            <ZoomOut size={16} />
          </button>
          <button className="icon-btn" style={{ backgroundColor: 'var(--bg-surface)', border: '1px solid var(--border-subtle)' }}>
            <Crosshair size={16} />
          </button>
        </div>

        {/* Floating Toolbar */}
        <div
          className="absolute flex items-center gap-2 px-3 py-1.5"
          style={{
            top: 12,
            right: 12,
            backgroundColor: 'var(--bg-surface)',
            border: '1px solid var(--border-subtle)',
            borderRadius: 6,
          }}
        >
          <label className="flex items-center gap-1.5 cursor-pointer">
            <input
              type="checkbox"
              checked={showRange}
              onChange={(e) => setShowRange(e.target.checked)}
              style={{ accentColor: 'var(--accent)', width: 12, height: 12 }}
            />
            <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>Range</span>
          </label>
          <div style={{ width: 1, height: 12, backgroundColor: 'var(--border-subtle)' }} />
          <label className="flex items-center gap-1.5 cursor-pointer">
            <input
              type="checkbox"
              checked={showConnections}
              onChange={(e) => setShowConnections(e.target.checked)}
              style={{ accentColor: 'var(--accent)', width: 12, height: 12 }}
            />
            <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>Links</span>
          </label>
        </div>
      </div>

      {/* Detail Panel */}
      <div
        className="flex flex-col flex-shrink-0 h-full"
        style={{
          width: 260,
          backgroundColor: 'var(--bg-surface)',
          borderLeft: '1px solid var(--border-subtle)',
        }}
      >
        <div className="p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>
            Nodes with Position
          </span>
          <span className="text-xs-muted ml-2">({state.nodes.length})</span>
        </div>

        <div className="flex-1 overflow-y-auto">
          {state.nodes.map((node) => (
            <button
              key={node.id}
              onClick={() => setSelectedNodeId(node.id === selectedNodeId ? null : node.id)}
              className="flex flex-col w-full text-left px-3 py-2 transition-colors"
              style={{
                borderBottom: '1px solid var(--border-subtle)',
                backgroundColor: selectedNodeId === node.id ? 'var(--accent-dim)' : 'transparent',
              }}
            >
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
                <span style={{ fontSize: 12, fontWeight: 500, color: 'var(--text-primary)' }}>
                  {node.longName}
                </span>
              </div>
              <span className="font-mono-tech text-xs-muted ml-4">
                {node.lat.toFixed(4)}, {node.lon.toFixed(4)}
              </span>
            </button>
          ))}
        </div>

        {/* Selected Node Info */}
        {selectedNode && (
          <div className="p-3" style={{ borderTop: '1px solid var(--border-subtle)', backgroundColor: 'var(--bg-elevated)' }}>
            <div className="flex items-center gap-2 mb-2">
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--accent)' }}>
                {selectedNode.longName}
              </span>
              <span className="badge font-mono-tech">{selectedNode.shortName}</span>
            </div>
            <div className="font-mono-tech text-xs-muted mb-1">{selectedNode.id}</div>
            <div className="grid grid-cols-2 gap-2 mt-2">
              <div className="flex flex-col">
                <span className="text-xs-muted">Battery</span>
                <span style={{ fontSize: 12, color: selectedNode.battery > 50 ? 'var(--accent)' : selectedNode.battery > 20 ? 'var(--warning)' : 'var(--danger)' }}>
                  {selectedNode.battery}%
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs-muted">Signal</span>
                <span className="font-mono-tech" style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                  {selectedNode.rssi}dBm
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
