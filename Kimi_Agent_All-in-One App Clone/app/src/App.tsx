import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppProvider } from '@/store/AppContext';
import { Sidebar } from '@/components/Sidebar';
import { ToastContainer } from '@/components/ToastContainer';
import { Messages } from '@/pages/Messages';
import { Nodes } from '@/pages/Nodes';
import { MapPage } from '@/pages/MapPage';
import { Network } from '@/pages/Network';
import { Settings } from '@/pages/Settings';

function AppLayout() {
  return (
    <div className="flex h-screen w-screen overflow-hidden" style={{ backgroundColor: 'var(--bg-base)' }}>
      <Sidebar />
      <div className="flex-1 overflow-hidden">
        <Routes>
          <Route path="/" element={<Messages />} />
          <Route path="/messages" element={<Messages />} />
          <Route path="/nodes" element={<Nodes />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/network" element={<Network />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
      <ToastContainer />
    </div>
  );
}

function App() {
  return (
    <AppProvider>
      <HashRouter>
        <AppLayout />
      </HashRouter>
    </AppProvider>
  );
}

export default App;