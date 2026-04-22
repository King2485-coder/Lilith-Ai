import { useApp } from '@/store/AppContext';
import { X, CheckCircle, AlertTriangle, AlertCircle, Info } from 'lucide-react';

const iconMap = {
  success: CheckCircle,
  warning: AlertTriangle,
  error: AlertCircle,
  info: Info,
};

const borderColorMap = {
  success: 'var(--accent)',
  warning: 'var(--warning)',
  error: 'var(--danger)',
  info: 'var(--info)',
};

const iconColorMap = {
  success: 'var(--accent)',
  warning: 'var(--warning)',
  error: 'var(--danger)',
  info: 'var(--info)',
};

export function ToastContainer() {
  const { state, removeToast } = useApp();

  return (
    <div
      className="fixed flex flex-col"
      style={{ top: 12, right: 12, gap: 8, zIndex: 9999 }}
    >
      {state.toasts.map((toast) => {
        const Icon = iconMap[toast.type];
        return (
          <div
            key={toast.id}
            className="slide-in-right flex items-center gap-3"
            style={{
              backgroundColor: 'var(--bg-elevated)',
              borderLeft: `3px solid ${borderColorMap[toast.type]}`,
              borderRadius: 6,
              padding: '10px 14px',
              minWidth: 240,
              maxWidth: 360,
              boxShadow: '0 4px 16px rgba(0,0,0,0.3)',
            }}
          >
            <Icon size={16} style={{ color: iconColorMap[toast.type], flexShrink: 0 }} />
            <span
              className="flex-1"
              style={{ fontSize: 12, color: 'var(--text-primary)', lineHeight: 1.4 }}
            >
              {toast.message}
            </span>
            <button
              onClick={() => removeToast(toast.id)}
              className="icon-btn"
              style={{ width: 20, height: 20 }}
            >
              <X size={12} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
