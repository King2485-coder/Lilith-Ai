import { useState, useRef, useEffect, useCallback } from 'react';
import { useApp } from '@/store/AppContext';
import { RotateCcw, Play, Square } from 'lucide-react';

interface GraphNode {
  id: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  label: string;
  longName: string;
  online: boolean;
  isMyNode: boolean;
}

interface GraphEdge {
  from: string;
  to: string;
  direct: boolean;
}

export function Network() {
  const { state } = useApp();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [physicsEnabled, setPhysicsEnabled] = useState(true);
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const graphRef = useRef<{ nodes: GraphNode[]; edges: GraphEdge[] }>({ nodes: [], edges: [] });
  const animRef = useRef<number>(0);
  const isDragging = useRef(false);
  const dragNode = useRef<string | null>(null);

  const initGraph = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const w = canvas.width;
    const h = canvas.height;
    const centerX = w / 2;
    const centerY = h / 2;

    const nodes: GraphNode[] = state.nodes.map((node, i) => {
      const angle = (i / state.nodes.length) * Math.PI * 2;
      const dist = 80 + Math.random() * 60;
      return {
        id: node.id,
        x: centerX + Math.cos(angle) * dist,
        y: centerY + Math.sin(angle) * dist,
        vx: 0,
        vy: 0,
        radius: node.id === '!a1b2c3' ? 16 : 12,
        label: node.shortName,
        longName: node.longName,
        online: node.online,
        isMyNode: node.id === '!a1b2c3',
      };
    });

    const edges: GraphEdge[] = [];
    for (let i = 1; i < state.nodes.length; i++) {
      if (state.nodes[i].online) {
        edges.push({ from: '!a1b2c3', to: state.nodes[i].id, direct: state.nodes[i].hops <= 1 });
      }
    }
    // Add some secondary connections
    edges.push({ from: '!7c1a45', to: '!c6g323', direct: true });
    edges.push({ from: '!9b4c89', to: '!d8e101', direct: false });

    graphRef.current = { nodes, edges };
  }, [state.nodes]);

  const updatePhysics = useCallback(() => {
    const graph = graphRef.current;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const w = canvas.width;
    const h = canvas.height;

    const centerX = w / 2;
    const centerY = h / 2;

    // Apply forces
    for (const node of graph.nodes) {
      if (dragNode.current === node.id) continue;

      // Center gravity
      node.vx += (centerX - node.x) * 0.0003;
      node.vy += (centerY - node.y) * 0.0003;

      // Repulsion between nodes
      for (const other of graph.nodes) {
        if (node.id === other.id) continue;
        const dx = node.x - other.x;
        const dy = node.y - other.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const force = 1200 / (dist * dist);
        node.vx += (dx / dist) * force;
        node.vy += (dy / dist) * force;
      }
    }

    // Spring force for edges
    for (const edge of graph.edges) {
      const from = graph.nodes.find(n => n.id === edge.from);
      const to = graph.nodes.find(n => n.id === edge.to);
      if (!from || !to) continue;

      const dx = to.x - from.x;
      const dy = to.y - from.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const targetDist = edge.direct ? 100 : 160;
      const force = (dist - targetDist) * 0.008;

      from.vx += (dx / dist) * force;
      from.vy += (dy / dist) * force;
      to.vx -= (dx / dist) * force;
      to.vy -= (dy / dist) * force;
    }

    // Apply velocity and damping
    for (const node of graph.nodes) {
      if (dragNode.current === node.id) continue;
      node.vx *= 0.92;
      node.vy *= 0.92;
      node.x += node.vx;
      node.y += node.vy;

      // Boundary
      node.x = Math.max(40, Math.min(w - 40, node.x));
      node.y = Math.max(40, Math.min(h - 40, node.y));
    }
  }, []);

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const w = canvas.width;
    const h = canvas.height;

    // Background
    ctx.fillStyle = '#0B0F0A';
    ctx.fillRect(0, 0, w, h);

    // Subtle grid
    ctx.strokeStyle = '#111a10';
    ctx.lineWidth = 0.5;
    for (let x = 0; x < w; x += 40) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }
    for (let y = 0; y < h; y += 40) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    const graph = graphRef.current;

    // Draw edges
    for (const edge of graph.edges) {
      const from = graph.nodes.find(n => n.id === edge.from);
      const to = graph.nodes.find(n => n.id === edge.to);
      if (!from || !to) continue;

      ctx.strokeStyle = edge.direct ? 'rgba(74, 222, 69, 0.35)' : 'rgba(74, 222, 69, 0.15)';
      ctx.lineWidth = edge.direct ? 1.5 : 1;
      if (!edge.direct) ctx.setLineDash([6, 4]);
      ctx.beginPath();
      ctx.moveTo(from.x, from.y);
      ctx.lineTo(to.x, to.y);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Draw nodes
    for (const node of graph.nodes) {
      const isSelected = selectedNodeId === node.id;

      // Glow for my node
      if (node.isMyNode) {
        ctx.fillStyle = 'rgba(74, 222, 69, 0.08)';
        ctx.beginPath();
        ctx.arc(node.x, node.y, node.radius + 12, 0, Math.PI * 2);
        ctx.fill();
      }

      // Selection ring
      if (isSelected) {
        ctx.strokeStyle = 'rgba(74, 222, 69, 0.5)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(node.x, node.y, node.radius + 6, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Node body
      if (node.isMyNode) {
        ctx.fillStyle = 'var(--accent)';
      } else if (node.online) {
        ctx.fillStyle = 'var(--bg-elevated)';
      } else {
        ctx.fillStyle = '#1a2218';
      }
      ctx.strokeStyle = node.online ? (node.isMyNode ? 'var(--accent)' : 'var(--accent)') : 'var(--text-muted)';
      ctx.lineWidth = node.isMyNode ? 2.5 : 1.5;
      ctx.beginPath();
      ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();

      // Inner dot for my node
      if (node.isMyNode) {
        ctx.fillStyle = '#0B0F0A';
        ctx.beginPath();
        ctx.arc(node.x, node.y, 5, 0, Math.PI * 2);
        ctx.fill();
      }

      // Label
      ctx.fillStyle = node.online ? 'var(--text-primary)' : 'var(--text-muted)';
      ctx.font = `${isSelected ? '600' : '500'} 11px Inter, sans-serif`;
      ctx.textAlign = 'center';
      ctx.fillText(node.label, node.x, node.y + node.radius + 16);
    }
  }, [selectedNodeId]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resize = () => {
      const parent = canvas.parentElement;
      if (!parent) return;
      canvas.width = parent.clientWidth;
      canvas.height = parent.clientHeight;
    };

    resize();
    initGraph();
    window.addEventListener('resize', resize);

    const loop = () => {
      if (physicsEnabled) updatePhysics();
      draw();
      animRef.current = requestAnimationFrame(loop);
    };
    animRef.current = requestAnimationFrame(loop);

    return () => {
      window.removeEventListener('resize', resize);
      cancelAnimationFrame(animRef.current);
    };
  }, [initGraph, updatePhysics, draw, physicsEnabled]);

  const handleMouseDown = (e: React.MouseEvent) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;

    const graph = graphRef.current;
    for (const node of graph.nodes) {
      const dist = Math.sqrt((mx - node.x) ** 2 + (my - node.y) ** 2);
      if (dist < node.radius + 6) {
        isDragging.current = true;
        dragNode.current = node.id;
        setSelectedNodeId(node.id);
        return;
      }
    }
    setSelectedNodeId(null);
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging.current || !dragNode.current) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const node = graphRef.current.nodes.find(n => n.id === dragNode.current);
    if (node) {
      node.x = e.clientX - rect.left;
      node.y = e.clientY - rect.top;
      node.vx = 0;
      node.vy = 0;
    }
  };

  const handleMouseUp = () => {
    isDragging.current = false;
    dragNode.current = null;
  };

  const selectedNode = state.nodes.find(n => n.id === selectedNodeId);
  const totalLinks = graphRef.current.edges.length;
  const onlineNodes = state.nodes.filter(n => n.online).length;

  return (
    <div className="flex h-full">
      {/* Detail Panel */}
      <div
        className="flex flex-col flex-shrink-0 h-full"
        style={{
          width: 260,
          backgroundColor: 'var(--bg-surface)',
          borderRight: '1px solid var(--border-subtle)',
        }}
      >
        {/* Stats */}
        <div className="p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          <div className="grid grid-cols-2 gap-2">
            {[
              { label: 'Nodes', value: state.nodes.length },
              { label: 'Active Links', value: totalLinks },
              { label: 'Online', value: onlineNodes, color: 'var(--accent)' },
              { label: 'Offline', value: state.nodes.length - onlineNodes, color: 'var(--text-muted)' },
            ].map((stat) => (
              <div
                key={stat.label}
                className="flex flex-col p-2"
                style={{
                  backgroundColor: 'var(--bg-elevated)',
                  borderRadius: 6,
                  border: '1px solid var(--border-subtle)',
                }}
              >
                <span style={{ fontSize: 16, fontWeight: 700, color: stat.color || 'var(--text-primary)' }}>
                  {stat.value}
                </span>
                <span className="text-xs-muted">{stat.label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Legend */}
        <div className="p-3" style={{ borderBottom: '1px solid var(--border-subtle)' }}>
          <div className="section-header" style={{ padding: '0 0 8px' }}>Legend</div>
          <div className="flex flex-col gap-1.5">
            {[
              { label: 'My Node', color: 'var(--accent)', filled: true },
              { label: 'Online', color: 'var(--accent)', filled: false },
              { label: 'Offline', color: 'var(--text-muted)', filled: false },
            ].map(item => (
              <div key={item.label} className="flex items-center gap-2">
                <div
                  style={{
                    width: 10,
                    height: 10,
                    borderRadius: '50%',
                    backgroundColor: item.filled ? item.color : 'transparent',
                    border: `1.5px solid ${item.color}`,
                  }}
                />
                <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{item.label}</span>
              </div>
            ))}
            <div className="flex items-center gap-2 mt-1">
              <div style={{ width: 16, height: 0, borderTop: '2px solid rgba(74, 222, 69, 0.35)' }} />
              <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>Direct link</span>
            </div>
            <div className="flex items-center gap-2">
              <div style={{ width: 16, height: 0, borderTop: '2px dashed rgba(74, 222, 69, 0.15)' }} />
              <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>Routed</span>
            </div>
          </div>
        </div>

        {/* Selected Node Info */}
        {selectedNode && (
          <div className="p-3" style={{ borderTop: '1px solid var(--border-subtle)', backgroundColor: 'var(--bg-elevated)' }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--accent)' }}>
              {selectedNode.longName}
            </span>
            <div className="font-mono-tech text-xs-muted mt-1">{selectedNode.id}</div>
            <div className="grid grid-cols-2 gap-2 mt-2">
              <div>
                <span className="text-xs-muted">Battery</span>
                <div style={{ fontSize: 12, color: selectedNode.battery > 50 ? 'var(--accent)' : 'var(--warning)' }}>
                  {selectedNode.battery}%
                </div>
              </div>
              <div>
                <span className="text-xs-muted">Hops</span>
                <div className="font-mono-tech" style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                  {selectedNode.hops}h
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Canvas Area */}
      <div className="flex-1 relative" style={{ backgroundColor: 'var(--bg-base)' }}>
        <canvas
          ref={canvasRef}
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={handleMouseUp}
          onMouseLeave={handleMouseUp}
          style={{
            width: '100%',
            height: '100%',
            cursor: isDragging.current ? 'grabbing' : 'grab',
          }}
        />

        {/* Floating Toolbar */}
        <div
          className="absolute flex items-center gap-1 px-2 py-1"
          style={{
            top: 12,
            right: 12,
            backgroundColor: 'var(--bg-surface)',
            border: '1px solid var(--border-subtle)',
            borderRadius: 6,
          }}
        >
          <button
            onClick={() => setPhysicsEnabled(!physicsEnabled)}
            className="icon-btn"
            title={physicsEnabled ? 'Pause physics' : 'Resume physics'}
          >
            {physicsEnabled ? <Square size={13} /> : <Play size={13} />}
          </button>
          <button
            onClick={() => { initGraph(); }}
            className="icon-btn"
            title="Reset view"
          >
            <RotateCcw size={13} />
          </button>
        </div>
      </div>
    </div>
  );
}
