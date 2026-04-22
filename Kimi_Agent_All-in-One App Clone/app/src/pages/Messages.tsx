import { useState, useRef, useEffect } from 'react';
import { useApp } from '@/store/AppContext';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Send, Paperclip, Hash, Lock,
  ChevronRight, Bluetooth, Wifi, Usb,
  Radio
} from 'lucide-react';

export function Messages() {
  const {
    state, sendMessage, selectChannel, selectDM,
    setViewMode, connect, disconnect
  } = useApp();
  const [inputValue, setInputValue] = useState('');
  const [showConnectModal, setShowConnectModal] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const currentMessages = state.viewMode === 'dms' && state.selectedDMNodeId
    ? (state.dmThreads[state.selectedDMNodeId]?.messages || [])
    : (state.messages[state.selectedChannelId] || []);

  const currentTitle = state.viewMode === 'dms' && state.selectedDMNodeId
    ? state.dmThreads[state.selectedDMNodeId]?.nodeName || 'Direct Message'
    : state.channels.find(ch => ch.id === state.selectedChannelId)?.name || 'Messages';

  const currentSubtitle = state.viewMode === 'dms' && state.selectedDMNodeId
    ? state.dmThreads[state.selectedDMNodeId]?.nodeShortName || ''
    : `${state.nodes.filter(n => n.online).length} nodes online`;

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [currentMessages.length]);

  const handleSend = () => {
    if (!inputValue.trim()) return;
    sendMessage(inputValue.trim());
    setInputValue('');
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleTextareaInput = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setInputValue(e.target.value);
    e.target.style.height = 'auto';
    e.target.style.height = Math.min(e.target.scrollHeight, 120) + 'px';
  };

  return (
    <div className="flex h-full">
      {/* Detail Panel - 280px */}
      <div
        className="flex flex-col flex-shrink-0 h-full"
        style={{
          width: 280,
          backgroundColor: 'var(--bg-surface)',
          borderRight: '1px solid var(--border-subtle)',
        }}
      >
        {/* Connection Bar */}
        <div
          className="flex items-center justify-between px-3"
          style={{ height: 44, borderBottom: '1px solid var(--border-subtle)' }}
        >
          <div className="flex items-center gap-2">
            <div
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                backgroundColor: state.connection.status === 'connected' ? 'var(--accent)' : state.connection.status === 'connecting' ? 'var(--warning)' : 'var(--danger)',
                boxShadow: state.connection.status === 'connected' ? '0 0 6px var(--accent)' : 'none',
              }}
            />
            <span className="text-sm-secondary">
              {state.connection.status === 'connected'
                ? state.connection.type === 'serial' ? 'Serial' : state.connection.type === 'bluetooth' ? 'BLE' : 'WiFi'
                : state.connection.status === 'connecting' ? 'Connecting...' : 'Disconnected'}
            </span>
          </div>
          {state.connection.status === 'connected' ? (
            <button onClick={disconnect} className="btn-ghost" style={{ fontSize: 11, padding: '3px 8px' }}>
              Disconnect
            </button>
          ) : (
            <button onClick={() => setShowConnectModal(true)} className="btn-primary" style={{ fontSize: 11, padding: '3px 10px' }}>
              Connect
            </button>
          )}
        </div>

        {/* Channel List */}
        <div className="section-header">Channels</div>
        <div className="flex flex-col">
          {state.channels.map((ch) => (
            <button
              key={ch.id}
              onClick={() => { selectChannel(ch.id); setViewMode('channels'); }}
              className="flex items-center gap-2.5 px-3 py-2 text-left transition-colors"
              style={{
                backgroundColor: state.viewMode === 'channels' && state.selectedChannelId === ch.id ? 'var(--accent-dim)' : 'transparent',
                borderLeft: state.viewMode === 'channels' && state.selectedChannelId === ch.id ? '3px solid var(--accent)' : '3px solid transparent',
              }}
            >
              {ch.encrypted ? (
                <Lock size={14} style={{ color: 'var(--text-muted)' }} />
              ) : (
                <Hash size={14} style={{ color: 'var(--text-muted)' }} />
              )}
              <span
                className="flex-1"
                style={{
                  fontSize: 13,
                  fontWeight: 500,
                  color: state.viewMode === 'channels' && state.selectedChannelId === ch.id ? 'var(--accent)' : 'var(--text-primary)',
                }}
              >
                {ch.name}
              </span>
              {ch.unread > 0 && (
                <span className="badge">{ch.unread}</span>
              )}
            </button>
          ))}
        </div>

        {/* Direct Messages */}
        <div className="section-header">Direct Messages</div>
        <div className="flex flex-col">
          {Object.values(state.dmThreads).map((thread) => (
            <button
              key={thread.nodeId}
              onClick={() => { selectDM(thread.nodeId); setViewMode('dms'); }}
              className="flex items-center gap-2.5 px-3 py-2 text-left transition-colors"
              style={{
                backgroundColor: state.viewMode === 'dms' && state.selectedDMNodeId === thread.nodeId ? 'var(--accent-dim)' : 'transparent',
                borderLeft: state.viewMode === 'dms' && state.selectedDMNodeId === thread.nodeId ? '3px solid var(--accent)' : '3px solid transparent',
              }}
            >
              <div className="relative flex-shrink-0">
                <div
                  className="flex items-center justify-center"
                  style={{
                    width: 24,
                    height: 24,
                    borderRadius: '50%',
                    backgroundColor: 'var(--bg-elevated)',
                    border: '1px solid var(--border-default)',
                    fontSize: 9,
                    fontWeight: 600,
                    color: 'var(--text-secondary)',
                  }}
                >
                  {thread.nodeShortName.slice(0, 2)}
                </div>
                <div
                  style={{
                    position: 'absolute',
                    bottom: -1,
                    right: -1,
                    width: 7,
                    height: 7,
                    borderRadius: '50%',
                    backgroundColor: thread.online ? 'var(--accent)' : 'var(--text-muted)',
                    border: '2px solid var(--bg-surface)',
                  }}
                />
              </div>
              <div className="flex-1 min-w-0">
                <div
                  className="truncate"
                  style={{
                    fontSize: 12,
                    fontWeight: 500,
                    color: state.viewMode === 'dms' && state.selectedDMNodeId === thread.nodeId ? 'var(--accent)' : 'var(--text-primary)',
                  }}
                >
                  {thread.nodeName}
                </div>
                <div className="truncate text-xs-muted">
                  {thread.messages[thread.messages.length - 1]?.content.slice(0, 30) || 'No messages'}
                </div>
              </div>
              {thread.unread > 0 && (
                <div
                  style={{
                    width: 7,
                    height: 7,
                    borderRadius: '50%',
                    backgroundColor: 'var(--accent)',
                    flexShrink: 0,
                  }}
                />
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Content Area */}
      <div className="flex flex-col flex-1 h-full" style={{ backgroundColor: 'var(--bg-base)' }}>
        {/* Message Header */}
        <div
          className="flex items-center justify-between px-4"
          style={{
            height: 48,
            borderBottom: '1px solid var(--border-subtle)',
            backgroundColor: 'var(--bg-surface)',
          }}
        >
          <div className="flex items-center gap-2">
            <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-primary)' }}>
              {currentTitle}
            </span>
            <span className="text-xs-muted">{currentSubtitle}</span>
          </div>
          <div className="flex items-center gap-2">
            {state.viewMode === 'channels' && (
              <span className="badge">{state.channels.find(ch => ch.id === state.selectedChannelId)?.preset}</span>
            )}
          </div>
        </div>

        {/* Message History */}
        <div className="flex-1 overflow-y-auto px-4 py-3" style={{ scrollBehavior: 'smooth' }}>
          {currentMessages.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full" style={{ gap: 12 }}>
              <Radio size={48} style={{ color: 'var(--border-default)' }} strokeWidth={1} />
              <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>No messages yet</span>
              <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>Send a message to get started</span>
            </div>
          ) : (
            <div className="flex flex-col" style={{ gap: 8 }}>
              <AnimatePresence initial={false}>
                {currentMessages.map((msg) => (
                  <motion.div
                    key={msg.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.2 }}
                    className={`flex ${msg.isSelf ? 'justify-end' : 'justify-start'}`}
                  >
                    <div
                      className="flex flex-col"
                      style={{
                        maxWidth: '80%',
                        backgroundColor: msg.isSelf ? 'var(--bg-elevated)' : 'var(--bg-surface)',
                        borderRadius: 6,
                        padding: '8px 12px',
                        borderLeft: msg.isSelf ? '2px solid var(--accent)' : '2px solid transparent',
                        border: `1px solid ${msg.isSelf ? 'var(--border-subtle)' : 'var(--border-subtle)'}`,
                      }}
                    >
                      <span
                        style={{
                          fontSize: 11,
                          fontWeight: 500,
                          color: msg.isSelf ? 'var(--text-secondary)' : 'var(--accent)',
                          marginBottom: 2,
                        }}
                      >
                        {msg.senderName}
                      </span>
                      <span style={{ fontSize: 13, color: 'var(--text-primary)', lineHeight: 1.5 }}>
                        {msg.content}
                      </span>
                      <span
                        className="self-end"
                        style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 4 }}
                      >
                        {msg.timestamp}
                      </span>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
              <div ref={messagesEndRef} />
            </div>
          )}
        </div>

        {/* Message Input */}
        <div
          className="flex items-end gap-2 px-4 py-2"
          style={{
            borderTop: '1px solid var(--border-subtle)',
            backgroundColor: 'var(--bg-surface)',
            minHeight: 56,
          }}
        >
          <button className="icon-btn mb-1" style={{ color: 'var(--text-muted)' }}>
            <Paperclip size={18} />
          </button>
          <textarea
            ref={textareaRef}
            value={inputValue}
            onChange={handleTextareaInput}
            onKeyDown={handleKeyDown}
            placeholder="Type a message..."
            rows={1}
            className="input-field flex-1 resize-none"
            style={{
              maxHeight: 120,
              minHeight: 32,
              padding: '6px 10px',
              fontSize: 13,
            }}
          />
          <button
            onClick={handleSend}
            disabled={!inputValue.trim()}
            className="flex items-center justify-center mb-1"
            style={{
              width: 32,
              height: 32,
              borderRadius: 6,
              backgroundColor: inputValue.trim() ? 'var(--accent)' : 'var(--border-default)',
              color: inputValue.trim() ? '#0B0F0A' : 'var(--text-muted)',
              transition: 'all 100ms ease',
              flexShrink: 0,
            }}
          >
            <Send size={15} />
          </button>
        </div>
      </div>

      {/* Connect Modal */}
      <AnimatePresence>
        {showConnectModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 flex items-center justify-center"
            style={{
              backgroundColor: 'rgba(0,0,0,0.6)',
              backdropFilter: 'blur(4px)',
              zIndex: 1000,
            }}
            onClick={() => setShowConnectModal(false)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              transition={{ duration: 0.2 }}
              onClick={(e) => e.stopPropagation()}
              className="panel"
              style={{
                width: 420,
                padding: '20px 24px',
                backgroundColor: 'var(--bg-surface)',
              }}
            >
              <h3 style={{ fontSize: 16, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 16 }}>
                Connect to Device
              </h3>
              <div className="flex flex-col" style={{ gap: 8 }}>
                {[
                  { type: 'serial' as const, icon: Usb, label: 'Serial', desc: 'USB serial connection' },
                  { type: 'bluetooth' as const, icon: Bluetooth, label: 'Bluetooth', desc: 'Bluetooth LE pairing' },
                  { type: 'wifi' as const, icon: Wifi, label: 'WiFi', desc: 'Network connection' },
                ].map(({ type, icon: Icon, label, desc }) => (
                  <button
                    key={type}
                    onClick={() => {
                      connect(type, `${label} Device`);
                      setShowConnectModal(false);
                    }}
                    className="flex items-center gap-3 p-3 text-left transition-colors"
                    style={{
                      borderRadius: 6,
                      border: '1px solid var(--border-subtle)',
                      backgroundColor: 'var(--bg-elevated)',
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.borderColor = 'var(--border-focus)';
                      e.currentTarget.style.backgroundColor = 'var(--bg-input)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.borderColor = 'var(--border-subtle)';
                      e.currentTarget.style.backgroundColor = 'var(--bg-elevated)';
                    }}
                  >
                    <Icon size={20} style={{ color: 'var(--accent)', flexShrink: 0 }} />
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-primary)' }}>{label}</div>
                      <div className="text-xs-muted">{desc}</div>
                    </div>
                    <ChevronRight size={16} style={{ color: 'var(--text-muted)', marginLeft: 'auto' }} />
                  </button>
                ))}
              </div>
              <button
                onClick={() => setShowConnectModal(false)}
                className="btn-secondary w-full mt-4"
              >
                Cancel
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
