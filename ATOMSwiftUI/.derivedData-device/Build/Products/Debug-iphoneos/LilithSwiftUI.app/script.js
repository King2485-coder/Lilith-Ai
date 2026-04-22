const dots = document.querySelectorAll('.toggle .dot');
const panes = {
  chat: document.querySelector('.pane-chat'),
  code: document.querySelector('.pane-code'),
  media: document.querySelector('.pane-media')
};

// Configurable backend base URL (prod + local fallback)
const apiCandidates = [
  window.ATOM_API_BASE, // optional override injected by deploy
  (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? `${window.location.protocol}//127.0.0.1:8000`
    : null,
  'https://api.lilithai.one'
].filter(Boolean);

let API_BASE_URL = apiCandidates[0];
let apiBaseReady = pickApiBase();

const TOKEN_KEY = 'lilith_token';
let authToken = localStorage.getItem(TOKEN_KEY) || null;
let authUser = null;

async function pickApiBase() {
  for (const base of apiCandidates) {
    try {
      const res = await fetch(`${base}/auth/me`, { method: 'GET' });
      // 401 is expected without token; treat any non-404 as existence
      if (res.status !== 404) {
        API_BASE_URL = base;
        return;
      }
    } catch (_) {
      // try next
    }
  }
  // fallback to first candidate if all probes failed
  API_BASE_URL = apiCandidates[0];
}

// Login modal wiring
const loginOverlay = document.querySelector('[data-modal="login"]');
const loginTrigger = document.querySelector('.login-trigger');
const getStartedTrigger = document.querySelector('.get-started');
const loginClose = document.querySelector('.modal .close');
const loginForm = document.querySelector('#login-form');
const registerForm = document.querySelector('#register-form');
const loginStatus = document.querySelector('#login-status');
const registerStatus = document.querySelector('#register-status');
const authTabs = document.querySelectorAll('.auth-tab');
const authPanels = document.querySelectorAll('.auth-panel');
const logoutActions = document.querySelectorAll('.logout-action');
const accountLinks = document.querySelectorAll('.account-link');
const isAppPage = document.body.dataset.page === 'app';

// Generic fetch helper with logging/error handling
async function callBackend(path, payload, method = 'POST') {
  await apiBaseReady;
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(authToken ? { Authorization: `Bearer ${authToken}` } : {})
    }
  };
  if (method !== 'GET') {
    options.body = JSON.stringify(payload || {});
  }
  console.log(`→ ${method} ${API_BASE_URL}${path}`, payload || null);
  const res = await fetch(`${API_BASE_URL}${path}`, options);
  const json = await res.json().catch(() => ({}));
  console.log(`← ${res.status} ${API_BASE_URL}${path}`, json);
  if (!res.ok) {
    throw new Error(json?.detail || json?.message || `Request failed (${res.status})`);
  }
  return json;
}

function openLogin() {
  loginOverlay?.classList.add('active');
  setAuthTab('login-form');
}

function closeLogin() {
  loginOverlay?.classList.remove('active');
}

function setAuthTab(targetId) {
  authTabs.forEach(btn => btn.classList.toggle('active', btn.dataset.target === targetId));
  authPanels.forEach(panel => panel.classList.toggle('active', panel.id === targetId));
  const title = document.getElementById('auth-modal-title');
  if (title) title.textContent = targetId === 'register-form' ? 'Create a Lilith account' : 'Log in to Lilith';
}

authTabs.forEach(btn => {
  btn.addEventListener('click', () => setAuthTab(btn.dataset.target));
});

loginTrigger?.addEventListener('click', (e) => { e.preventDefault(); openLogin(); });
getStartedTrigger?.addEventListener('click', (e) => { e.preventDefault(); openLogin(); });
loginClose?.addEventListener('click', closeLogin);
loginOverlay?.addEventListener('click', (e) => {
  if (e.target === loginOverlay) closeLogin();
});

loginForm?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = new FormData(loginForm);
  const email = data.get('email');
  const password = data.get('password');
  loginStatus.textContent = 'Signing in…';

  try {
    const json = await callBackend('/auth/login', { email, password });
    authToken = json.access_token;
    authUser = json.user;
    localStorage.setItem(TOKEN_KEY, authToken);
    loginStatus.textContent = 'Login success. Redirecting…';
    updateAuthUI();
    closeLogin();
    setTimeout(() => window.location.href = 'app.html', 300);
  } catch (err) {
    loginStatus.textContent = 'Login failed: ' + err.message;
  }
});

registerForm?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = new FormData(registerForm);
  const email = data.get('email');
  const password = data.get('password');
  registerStatus.textContent = 'Creating account…';
  try {
    const json = await callBackend('/auth/register', { email, password });
    authToken = json.access_token;
    authUser = json.user;
    localStorage.setItem(TOKEN_KEY, authToken);
    registerStatus.textContent = 'Account created. Redirecting…';
    updateAuthUI();
    closeLogin();
    setTimeout(() => window.location.href = 'app.html', 300);
  } catch (err) {
    registerStatus.textContent = 'Register failed: ' + err.message;
  }
});

logoutActions.forEach(btn => {
  btn.addEventListener('click', async (e) => {
    e.preventDefault();
    try { await callBackend('/auth/logout', {}, 'POST'); } catch (_) {}
    authToken = null;
    authUser = null;
    localStorage.removeItem(TOKEN_KEY);
    updateAuthUI();
    if (isAppPage) window.location.href = 'index.html';
  });
});

async function bootstrapAuth() {
  if (!authToken) {
    updateAuthUI();
    return;
  }
  try {
    const me = await callBackend('/auth/me', {}, 'GET');
    authUser = me;
    updateAuthUI();
  } catch (err) {
    console.warn('auth/me failed', err.message);
    authToken = null;
    authUser = null;
    localStorage.removeItem(TOKEN_KEY);
    updateAuthUI();
  }
}

function updateAuthUI() {
  const isAuthed = !!authToken && !!authUser;
  document.querySelectorAll('.login-trigger').forEach(el => el.style.display = isAuthed ? 'none' : '');
  accountLinks.forEach(el => el.style.display = isAuthed ? '' : 'none');
  logoutActions.forEach(el => el.style.display = isAuthed ? '' : 'none');
  if (loginStatus) loginStatus.textContent = isAuthed ? 'Signed in as ' + (authUser?.email || '') : 'Sign in securely to Lilith.';
  if (registerStatus) registerStatus.textContent = isAuthed ? 'Account ready.' : 'Create your Lilith account.';
  if (isAppPage && !isAuthed) {
    window.location.href = 'index.html';
  }
}

function setMode(mode) {
  dots.forEach(d => d.classList.toggle('active', d.dataset.mode === mode));
  Object.entries(panes).forEach(([key, pane]) => {
    if (!pane) return;
    pane.classList.toggle('active', key === mode);
  });
}

dots.forEach(dot => {
  dot.addEventListener('click', () => setMode(dot.dataset.mode));
});

// Auto-rotate modes every 4 seconds to hint at capability
const modes = ['chat', 'code', 'media'];
let idx = 0;
setInterval(() => {
  idx = (idx + 1) % modes.length;
  setMode(modes[idx]);
}, 4200);

// Start in chat mode
setMode('chat');

// Load session from storage and hydrate user state
bootstrapAuth();

// ---------- App workspace wiring ----------
if (isAppPage) {
  const appLede = document.getElementById('app-lede');
  const appChips = document.getElementById('app-chips');
  const logList = document.getElementById('app-log');

  const chatForm = document.getElementById('app-chat-form');
  const chatInput = document.getElementById('app-chat-input');
  const chatResp = document.getElementById('app-chat-response');

  const imageForm = document.getElementById('app-image-form');
  const imagePrompt = document.getElementById('app-image-prompt');
  const imagePreview = document.getElementById('app-image-preview');
  const imageStatus = document.getElementById('app-image-status');

  const codeForm = document.getElementById('app-code-form');
  const codeInput = document.getElementById('app-code-input');
  const codeResp = document.getElementById('app-code-response');

  const libraryGrid = document.getElementById('library-grid');
  const libraryEmpty = document.getElementById('library-empty');

  const role = localStorage.getItem('atomRole') || 'user';
  const plan = localStorage.getItem('atomPlan') || 'Starter';
  const credits = localStorage.getItem('atomCredits') || 'standard';
  const user = localStorage.getItem('atomUser') || 'Guest';
  const superAdmin = localStorage.getItem('atomSuperAdmin') === 'true';
  const toolbox = document.getElementById('toolbox');
  const toolboxToggle = document.getElementById('toolbox-toggle');

  toolboxToggle?.addEventListener('click', () => {
    toolbox?.classList.toggle('hidden');
    toolboxToggle.textContent = toolbox?.classList.contains('hidden') ? 'Toolbox' : 'Hide toolbox';
  });

  function appendLog(text) {
    if (!logList) return;
    const li = document.createElement('li');
    const now = new Date().toLocaleTimeString();
    li.textContent = `[${now}] ${text}`;
    logList.prepend(li);
  }

  function addToLibrary({ type = 'Item', title = 'New item', detail = '', mediaSrc = '' }) {
    if (!libraryGrid) return;
    if (libraryEmpty) libraryEmpty.style.display = 'none';

    const card = document.createElement('div');
    card.className = 'library-card';

    const meta = document.createElement('div');
    meta.className = 'library-meta';
    const pill = document.createElement('span');
    pill.className = 'pill';
    pill.textContent = type;
    const time = document.createElement('span');
    time.className = 'label';
    time.textContent = new Date().toLocaleTimeString();
    meta.append(pill, time);
    card.appendChild(meta);

    const titleEl = document.createElement('p');
    titleEl.className = 'library-title';
    titleEl.textContent = title;
    card.appendChild(titleEl);

    if (detail) {
      const detailEl = document.createElement('p');
      detailEl.className = 'library-detail';
      detailEl.textContent = detail;
      card.appendChild(detailEl);
    }

    if (mediaSrc) {
      const img = document.createElement('img');
      img.className = 'library-thumb';
      img.src = mediaSrc;
      img.alt = title;
      card.appendChild(img);
    }

    libraryGrid.prepend(card);
  }

  function setSessionUI() {
    if (appLede) appLede.textContent = superAdmin ? 'Super Admin access granted. All features unlocked.' : 'Standard workspace ready.';

    const chipList = [
      ...(superAdmin ? ['Unlimited features'] : [])
    ];
    if (appChips) {
      appChips.innerHTML = '';
      chipList.forEach(text => {
        const span = document.createElement('span');
        span.className = 'chip';
        span.textContent = text;
        appChips.appendChild(span);
      });
    }
  }

  chatForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const message = (chatInput.value || '').trim();
    if (!message) return;
    chatResp.textContent = 'Thinking…';
    appendLog('Chat → ' + message);
    try {
      const json = await callBackend('/api/chat', { message });
      chatResp.textContent = JSON.stringify(json, null, 2);
      appendLog('Chat ✓');
      addToLibrary({
        type: 'Chat',
        title: 'Reply',
        detail: json?.message || json?.reply || json?.content || 'Chat response'
      });
    } catch (err) {
      chatResp.textContent = 'Chat failed: ' + err.message;
      appendLog('Chat failed');
    }
  });
  // allow Enter to submit
  chatInput?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      chatForm?.dispatchEvent(new Event('submit'));
    }
  });

  imageForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = imagePrompt.value.trim();
    if (!prompt) return;
    imageStatus.textContent = 'Generating…';
    appendLog('Image → ' + prompt);
    try {
      const json = await callBackend('/api/image/generate', { prompt });
      if (json?.imageData) {
        const src = `data:image/png;base64,${json.imageData}`;
        imagePreview.src = src;
        imageStatus.textContent = json.textResponse || 'Generated.';
        addToLibrary({
          type: 'Image',
          title: prompt || 'Generated image',
          detail: json.textResponse || 'Image ready',
          mediaSrc: src
        });
      } else {
        imageStatus.textContent = 'No image data returned.';
      }
      appendLog('Image ✓');
    } catch (err) {
      imageStatus.textContent = 'Image failed: ' + err.message;
      appendLog('Image failed');
    }
  });

  codeForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = codeInput.value.trim();
    if (!prompt) return;
    codeResp.textContent = '// Working…';
    appendLog('Code assist → ' + prompt);
    try {
      const json = await callBackend('/api/code/assist', { prompt });
      codeResp.textContent = json?.content || '// No content';
      addToLibrary({
        type: 'Code',
        title: 'Code snippet',
        detail: (json?.content || '').slice(0, 220)
      });
      appendLog('Code assist ✓');
    } catch (err) {
      codeResp.textContent = '// Failed: ' + err.message;
      appendLog('Code assist failed');
    }
  });

  setSessionUI();

  // Agents & modes
  const agentSelect = document.getElementById('agent-select');
  const modeSelect = document.getElementById('mode-select');
  const agentModeLabel = document.getElementById('agent-mode-label');

  function updateAgentModeLabel() {
    if (agentModeLabel) {
      agentModeLabel.textContent = `${agentSelect?.value || 'core'} · ${modeSelect?.value || 'chat'}`;
    }
  }

  async function loadAgents() {
    try {
      const data = await callBackend('/api/agents', {}, 'GET');
      const agents = data?.agents || [];
      const modes = data?.modes || [];
      if (agentSelect) {
        agentSelect.innerHTML = '';
        agents.forEach(a => {
          const opt = document.createElement('option');
          opt.value = a.id;
          opt.textContent = a.name;
          agentSelect.appendChild(opt);
        });
        const storedAgent = localStorage.getItem('atomAgent');
        if (storedAgent) agentSelect.value = storedAgent;
      }
      if (modeSelect) {
        modeSelect.innerHTML = '';
        modes.forEach(m => {
          const opt = document.createElement('option');
          opt.value = m;
          opt.textContent = m;
          modeSelect.appendChild(opt);
        });
        const storedMode = localStorage.getItem('atomMode');
        if (storedMode) modeSelect.value = storedMode;
      }
      updateAgentModeLabel();
    } catch (err) {
      appendLog('Agents failed: ' + err.message);
    }
  }

  agentSelect?.addEventListener('change', () => {
    localStorage.setItem('atomAgent', agentSelect.value);
    updateAgentModeLabel();
  });
  modeSelect?.addEventListener('change', () => {
    localStorage.setItem('atomMode', modeSelect.value);
    updateAgentModeLabel();
  });

  // Video generate
  const videoForm = document.getElementById('app-video-form');
  const videoPrompt = document.getElementById('app-video-prompt');
  const videoThumb = document.getElementById('app-video-thumb');
  const videoStatus = document.getElementById('app-video-status');

  videoForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = videoPrompt.value.trim();
    if (!prompt) return;
    videoStatus.textContent = 'Rendering…';
    appendLog('Video gen → ' + prompt);
    try {
      const json = await callBackend('/api/video/generate', { prompt });
      if (json.thumbnail) videoThumb.src = json.thumbnail.startsWith('data:') ? json.thumbnail : 'assets/lilith_neutral.png';
      videoStatus.textContent = json.textResponse || 'Rendered.';
      addToLibrary({
        type: 'Video',
        title: prompt || 'Video render',
        detail: json.textResponse || 'Rendered video',
        mediaSrc: json.thumbnail && json.thumbnail.startsWith('data:') ? json.thumbnail : ''
      });
      appendLog('Video gen ✓');
    } catch (err) {
      videoStatus.textContent = 'Video failed: ' + err.message;
      appendLog('Video gen failed');
    }
  });

  // Video upload remix
  const videoUploadForm = document.getElementById('app-video-upload-form');
  const videoFile = document.getElementById('app-video-file');
  const videoUploadStatus = document.getElementById('app-video-upload-status');

  videoUploadForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fileName = videoFile?.files?.[0]?.name;
    if (!fileName) {
      videoUploadStatus.textContent = 'Pick a file first.';
      return;
    }
    videoUploadStatus.textContent = 'Uploading…';
    appendLog('Video remix → ' + fileName);
    try {
      const json = await callBackend('/api/video/from-upload', { filename: fileName });
      videoUploadStatus.textContent = json.textResponse || 'Remixed.';
      addToLibrary({
        type: 'Video',
        title: `Remix: ${fileName}`,
        detail: json.textResponse || 'Video remixed'
      });
      appendLog('Video remix ✓');
    } catch (err) {
      videoUploadStatus.textContent = 'Upload failed: ' + err.message;
      appendLog('Video remix failed');
    }
  });

  // Site clone
  const cloneForm = document.getElementById('app-clone-form');
  const cloneUrl = document.getElementById('app-clone-url');
  const cloneResp = document.getElementById('app-clone-response');

  cloneForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const url = cloneUrl.value.trim();
    if (!url) return;
    cloneResp.textContent = 'Cloning…';
    appendLog('Clone → ' + url);
    try {
      const json = await callBackend('/api/clone', { url });
      cloneResp.textContent = json.html || 'No HTML returned.';
      addToLibrary({
        type: 'Clone',
        title: url,
        detail: (json.preview || json.html || '').slice(0, 220)
      });
      appendLog('Clone ✓');
    } catch (err) {
      cloneResp.textContent = 'Clone failed: ' + err.message;
      appendLog('Clone failed');
    }
  });

  // History
  const historyBtn = document.getElementById('app-history-load');
  const historyList = document.getElementById('app-history-list');

  historyBtn?.addEventListener('click', async () => {
    historyBtn.textContent = 'Loading…';
    appendLog('History → load');
    try {
      const json = await callBackend('/api/history', {}, 'GET');
      const items = json.items || [];
      historyList.innerHTML = '';
      items.forEach(item => {
        const li = document.createElement('li');
        li.textContent = `${item.title} (${item.timestamp})`;
        historyList.appendChild(li);
      });
      historyBtn.textContent = 'Load history';
      appendLog('History ✓');
    } catch (err) {
      historyBtn.textContent = 'Load history';
      appendLog('History failed');
    }
  });

  // Projects
  const projectsBtn = document.getElementById('app-projects-load');
  const projectsList = document.getElementById('app-projects-list');
  const projectSaveForm = document.getElementById('app-projects-save');
  const projectPath = document.getElementById('app-project-path');
  const projectContent = document.getElementById('app-project-content');
  const projectsStatus = document.getElementById('app-projects-status');

  projectsBtn?.addEventListener('click', async () => {
    projectsBtn.textContent = 'Loading…';
    appendLog('Projects → load');
    try {
      const json = await callBackend('/api/projects', {}, 'GET');
      const files = json.files || [];
      projectsList.innerHTML = '';
      files.forEach(f => {
        const li = document.createElement('li');
        li.textContent = `${f.path} (${f.size} bytes)`;
        projectsList.appendChild(li);
      });
      projectsBtn.textContent = 'Load files';
      appendLog('Projects ✓');
    } catch (err) {
      projectsBtn.textContent = 'Load files';
      appendLog('Projects failed');
    }
  });

  projectSaveForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const path = projectPath.value.trim();
    const content = projectContent.value.trim();
    if (!path) return;
    projectsStatus.textContent = 'Saving…';
    appendLog('Project save → ' + path);
    try {
      const json = await callBackend('/api/projects/save', { path, content });
      projectsStatus.textContent = json.message || 'Saved.';
      appendLog('Project save ✓');
    } catch (err) {
      projectsStatus.textContent = 'Save failed: ' + err.message;
      appendLog('Project save failed');
    }
  });

  // Billing
  const planBtn = document.getElementById('app-plan-btn');
  const creditsSelect = document.getElementById('app-credits-select');
  const creditsBtn = document.getElementById('app-credits-btn');
  const billingStatus = document.getElementById('app-billing-status');

  planBtn?.addEventListener('click', async () => {
    billingStatus.textContent = 'Starting checkout…';
    appendLog('Checkout → Pro');
    try {
      const json = await callBackend('/api/subscription/checkout', {});
      billingStatus.textContent = `Checkout URL: ${json.checkoutUrl}`;
      appendLog('Checkout ✓');
    } catch (err) {
      billingStatus.textContent = 'Checkout failed: ' + err.message;
      appendLog('Checkout failed');
    }
  });

  creditsBtn?.addEventListener('click', async () => {
    const packageSize = creditsSelect.value;
    billingStatus.textContent = 'Buying credits…';
    appendLog('Credits → ' + packageSize);
    try {
      const json = await callBackend('/api/credits/buy', { package: packageSize, superAdmin });
      billingStatus.textContent = `Added ${json.creditsAdded}; total: ${json.totalCredits}`;
      appendLog('Credits ✓');
    } catch (err) {
      billingStatus.textContent = 'Credits failed: ' + err.message;
      appendLog('Credits failed');
    }
  });

  loadAgents();
}
