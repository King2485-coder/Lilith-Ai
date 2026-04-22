const dots = document.querySelectorAll('.toggle .dot');
const panes = {
  chat: document.querySelector('.pane-chat'),
  code: document.querySelector('.pane-code'),
  media: document.querySelector('.pane-media')
};

const isHttpOrigin = window.location.origin && window.location.origin.startsWith('http');
const sameOriginBase = isHttpOrigin ? window.location.origin : null;

// Configurable backend base URL (prod + local fallback)
const apiCandidates = [...new Set([
  window.LILITH_API_BASE || window.ATOM_API_BASE, // optional override injected by deploy
  sameOriginBase,
  (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? `${window.location.protocol}//127.0.0.1:8000`
    : null,
  (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? `${window.location.protocol}//localhost:8000`
    : null,
  'https://api.lilithai.one'
].filter(Boolean))];

let API_BASE_URL = apiCandidates[0];
let apiBaseReady = pickApiBase();

const TOKEN_KEY = 'lilith_token';
let authToken = localStorage.getItem(TOKEN_KEY) || null;
let authUser = null;

function enforceLilithBranding() {
  const lilithTitle = isAppPage ? 'Lilith App' : 'Lilith — Everyday AI partner';
  document.title = lilithTitle;

  const badBrandingRegex = /(made with\s+[a-z]+|[a-z]+\s*\|\s*fullstack app)/i;
  document.querySelectorAll('meta[name="application-name"], meta[property="og:site_name"], meta[name="apple-mobile-web-app-title"]').forEach((meta) => {
    const value = meta.getAttribute('content') || '';
    if (badBrandingRegex.test(value)) {
      meta.setAttribute('content', 'Lilith');
    }
  });

  document.querySelectorAll('body *').forEach((node) => {
    if (node.children.length > 0) return;
    const text = (node.textContent || '').trim();
    if (!text) return;
    if (/made with\s+[a-z]+/i.test(text)) {
      node.remove();
      return;
    }
    if (badBrandingRegex.test(text)) {
      node.textContent = text
        .replace(/[a-z]+\s*\|\s*fullstack app/gi, 'Lilith')
        .replace(/made with\s+[a-z]+/gi, '')
        .replace(/\s{2,}/g, ' ')
        .trim();
    }
  });
}

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

function orderedApiBases() {
  return [API_BASE_URL, ...apiCandidates.filter((candidate) => candidate !== API_BASE_URL)];
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
  let lastError = null;

  for (let index = 0; index < orderedApiBases().length; index += 1) {
    const base = orderedApiBases()[index];
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

    try {
      console.log(`→ ${method} ${base}${path}`, payload || null);
      const res = await fetch(`${base}${path}`, options);
      const json = await res.json().catch(() => ({}));
      console.log(`← ${res.status} ${base}${path}`, json);

      if (res.ok) {
        API_BASE_URL = base;
        return json;
      }

      if ((res.status === 404 || res.status >= 500) && index < orderedApiBases().length - 1) {
        continue;
      }

      throw new Error(json?.detail || json?.message || `Request failed (${res.status})`);
    } catch (err) {
      lastError = err;
      if (index < orderedApiBases().length - 1) {
        continue;
      }
    }
  }

  throw lastError || new Error('Network Error: unable to reach Lilith backend');
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
enforceLilithBranding();
setTimeout(enforceLilithBranding, 250);
setTimeout(enforceLilithBranding, 1000);

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

  const role = localStorage.getItem('lilithRole') || localStorage.getItem('atomRole') || 'user';
  const plan = localStorage.getItem('lilithPlan') || localStorage.getItem('atomPlan') || 'Starter';
  const credits = localStorage.getItem('lilithCredits') || localStorage.getItem('atomCredits') || 'standard';
  const user = localStorage.getItem('lilithUser') || localStorage.getItem('atomUser') || 'Guest';
  const superAdmin = (localStorage.getItem('lilithSuperAdmin') || localStorage.getItem('atomSuperAdmin')) === 'true';
  const toolbox = document.getElementById('toolbox');
  const toolboxToggle = document.getElementById('toolbox-toggle');
  const toolsCatalog = document.getElementById('app-tools-catalog');
  const toolsSearch = document.getElementById('app-tools-search');
  const toolsDebugPanel = document.getElementById('app-tools-debug');
  const toolsDebugOutput = document.getElementById('app-tools-debug-output');
  const workspaceModal = document.getElementById('tool-workspace-modal');
  const workspaceBackButton = document.getElementById('workspace-back-btn');
  const workspaceTitle = document.getElementById('workspace-title');
  const workspacePrimaryButton = document.getElementById('workspace-primary-btn');
  const workspaceViews = {
    pdf_editor: document.getElementById('workspace-pdf_editor'),
    video_editor: document.getElementById('workspace-video_editor'),
    long_to_reels: document.getElementById('workspace-long_to_reels'),
    prompt_from_screenshot: document.getElementById('workspace-prompt_from_screenshot'),
    website_clone: document.getElementById('workspace-website_clone'),
    prompt_from_link: document.getElementById('workspace-prompt_from_link')
  };
  const workspaceToolIds = new Set(Object.keys(workspaceViews));

  const lilithTools = [
    { id: 'assistant_chat', title: 'Chat / Assistant', category: 'Create', route: '#app-chat-form', targetId: 'app-chat-form' },
    { id: 'pdf_editor', title: 'PDF Editor / Adobe Clone', category: 'Documents', route: '#tool-pdf-editor', targetId: 'tool-pdf-editor' },
    { id: 'website_clone', title: 'Website Clone / Clone Site', category: 'Web', route: '#tool-website-clone', targetId: 'tool-website-clone' },
    { id: 'prompt_from_link', title: 'Prompt From Link', category: 'Web', route: '#tool-prompt-link', targetId: 'tool-prompt-link' },
    { id: 'prompt_from_screenshot', title: 'Prompt From Screenshot', category: 'Media', route: '#tool-prompt-screenshot', targetId: 'tool-prompt-screenshot' },
    { id: 'video_editor', title: 'Video Editor / CapCut Clone', category: 'Media', route: '#tool-video-editor', targetId: 'tool-video-editor' },
    { id: 'long_to_reels', title: 'Long-form to Reels', category: 'Media', route: '#tool-video-reels', targetId: 'tool-video-reels' },
    { id: 'wealth_wizard', title: 'Wealth Wizard', category: 'Finance', route: '#tool-wealth-wizard', targetId: 'tool-wealth-wizard' },
    { id: 'legal_tools', title: 'Legal Tools', category: 'Legal', route: '#tool-legal-tools', targetId: 'tool-legal-tools' },
    { id: 'image_studio', title: 'Image Generation', category: 'Media', route: '#tool-image-generation', targetId: 'tool-image-generation' },
    { id: 'projects', title: 'Projects', category: 'Automation', route: '#tool-projects', targetId: 'tool-projects' },
    { id: 'history', title: 'Activity / History', category: 'Automation', route: '#tool-history', targetId: 'tool-history' }
  ];

  const workspaceTitles = {
    pdf_editor: 'PDF Editor',
    video_editor: 'Video Editor',
    long_to_reels: 'Reels Generator',
    prompt_from_screenshot: 'Screenshot Analyzer',
    website_clone: 'Website Clone',
    prompt_from_link: 'Prompt from Link'
  };

  let activeWorkspace = null;
  let lastClonedHtml = '';
  let activePdfTool = 'select';
  let activePdfPage = 1;
  let pdfZoom = 100;
  const pdfPages = [];
  const pdfState = {
    file: null,
    dataBuffer: null,
    pdfDoc: null,
    annotations: [],
    removedPages: new Set(),
    addedPages: 0
  };
  let pdfHistoryPointer = 0;
  const pdfHistory = ['Initial document state'];

  let videoPlayhead = 0;
  let selectedClipId = '';
  const videoClips = [];
  const videoState = {
    sourceFile: null,
    sourceUrl: '',
    duration: 0,
    objectUrl: '',
  };
  let videoPlayerNode = null;
  let tesseractWorker = null;
  let pdfJsApi = null;

  const reelsState = {
    clips: [],
    selected: new Set()
  };
  const navButtons = Array.from(document.querySelectorAll('#primary-nav .nav-pill'));
  const appViews = Array.from(document.querySelectorAll('.app-view'));
  const composerModal = document.getElementById('post-composer-modal');
  const openPostComposerBtn = document.getElementById('open-post-composer');
  const closePostComposerBtn = document.getElementById('close-post-composer');
  const submitPostBtn = document.getElementById('submit-post');
  const postCaptionInput = document.getElementById('post-caption');
  const postMediaInput = document.getElementById('post-media-file');
  const postAudienceSelect = document.getElementById('post-audience');
  const postStatus = document.getElementById('post-status');
  const toastNode = document.getElementById('app-toast');
  const socialFeedSkeleton = document.getElementById('social-feed-skeleton');
  const socialFeedList = document.getElementById('social-feed-list');
  const socialFeedSentinel = document.getElementById('social-feed-sentinel');
  const homeSocialSkeleton = document.getElementById('home-social-skeleton');
  const homeSocialList = document.getElementById('home-social-list');
  const messagesThreadList = document.getElementById('messages-thread-list');
  const threadPreview = document.getElementById('thread-preview');
  const threadTitle = document.getElementById('active-thread-title');
  const threadForm = document.getElementById('thread-message-form');
  const threadInput = document.getElementById('thread-message-input');
  const threadCallBtn = document.getElementById('thread-call-btn');
  const threadAttachBtn = document.getElementById('thread-attach-btn');
  const discoverSearch = document.getElementById('discover-search');
  const discoverResults = document.getElementById('discover-results');
  const notificationsList = document.getElementById('notifications-list');
  const notificationsEmpty = document.getElementById('notifications-empty');
  const homeNewPostBtn = document.getElementById('home-new-post');
  const homeStartCallBtn = document.getElementById('home-start-call');
  const profileMessageBtn = document.getElementById('profile-message-btn');
  const profileCallBtn = document.getElementById('profile-call-btn');
  const metricUnread = document.getElementById('metric-unread');
  const metricCalls = document.getElementById('metric-calls');
  const metricFollows = document.getElementById('metric-follows');
  const profilePostCount = document.getElementById('profile-post-count');
  const profileFollowerCount = document.getElementById('profile-follower-count');
  const profileFollowingCount = document.getElementById('profile-following-count');
  const profileFollowBtn = document.getElementById('profile-follow-btn');
  const profileTabs = Array.from(document.querySelectorAll('#profile-tabs .profile-tab'));
  const profileTabContent = document.getElementById('profile-tab-content');
  const commentsModal = document.getElementById('comments-modal');
  const closeCommentsModalBtn = document.getElementById('close-comments-modal');
  const postCommentBtn = document.getElementById('post-comment-btn');
  const commentsList = document.getElementById('comments-list');
  const commentInput = document.getElementById('comment-input');
  const threadTyping = document.getElementById('thread-typing');
  const osAiForm = document.getElementById('os-ai-form');
  const osAiInput = document.getElementById('os-ai-input');
  const osNotificationCount = document.getElementById('os-notification-count');
  const edgeOpenButtons = Array.from(document.querySelectorAll('[data-edge-open]'));
  const environmentObjects = Array.from(document.querySelectorAll('.env-object[data-env-target], .env-object[data-tool-id]'));
  const environmentDropzone = document.getElementById('center-dropzone');
  const environmentOverlayLog = document.getElementById('environment-overlay-log');
  const edgeToolChips = Array.from(document.querySelectorAll('.edge-tool-chip[data-tool-id]'));

  const socialState = {
    posts: [
      { id: 'p1', author: '@mira.codes', name: 'Mira', text: 'Just shipped a Lilith-powered creator workflow.', likes: 42, comments: [{by:'@ava',text:'So clean.'}], saves: 12, type: 'text', timestamp: '2m', active: true },
      { id: 'p2', author: '@kai.media', name: 'Kai', text: 'Turned one long-form clip into five reels in minutes.', likes: 81, comments: [{by:'@milo',text:'Need this flow.'}], saves: 24, type: 'video', media: 'assets/lilith_smirk.png', timestamp: '11m', active: true },
      { id: 'p3', author: '@sol.design', name: 'Sol', text: 'Shared my annotated PDF proposal directly from Lilith.', likes: 33, comments: [{by:'@rene',text:'This is polished.'}], saves: 8, type: 'document', timestamp: '24m', active: false },
    ],
    notifications: [
      'Ava liked your post',
      'Rene followed @lilith.user',
      'Milo mentioned you in a comment',
    ],
    threads: [
      { id: 't1', username: '@lilith.team', name: 'Lilith Team', unread: 2, active: true, messages: [{ from: 'them', text: 'Your export finished.', ts: '9:21 AM', read: true }, { from: 'me', text: 'Great, sending now.', ts: '9:22 AM', read: true }] },
      { id: 't2', username: '@ava', name: 'Ava', unread: 1, active: true, messages: [{ from: 'them', text: 'Can we call in 10?', ts: '9:40 AM', read: false }] },
      { id: 't3', username: '@kai.media', name: 'Kai', unread: 0, active: false, messages: [{ from: 'me', text: 'Loved your reels workflow.', ts: 'Yesterday', read: true }] },
    ],
    currentThreadId: 't1',
    discover: [
      { username: '@ava', name: 'Ava Monroe' },
      { username: '@milo', name: 'Milo Hart' },
      { username: '@kai.media', name: 'Kai Rivera' },
      { username: '@sol.design', name: 'Sol Park' },
    ],
  };
  const extraFeedSeed = [
    'Shared my weekend photo set from Lilith.',
    'Built a micro-site and posted it in one tap.',
    'Voice-called directly from profile, no number needed.',
    'Posted a tool output to feed and DMs at once.',
  ];
  let feedLoadIndex = 0;
  let activeCommentsPostId = null;

  toolboxToggle?.addEventListener('click', () => {
    setActiveView('tools');
    toolboxToggle.textContent = 'Hide toolbox';
  });

  navButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const target = button.getAttribute('data-view-target');
      if (!target) return;
      setActiveView(target);
      showToast(`${target[0].toUpperCase()}${target.slice(1)} ready`);
    });
  });

  document.querySelectorAll('[data-view-target]').forEach((node) => {
    node.addEventListener('click', () => {
      const target = node.getAttribute('data-view-target');
      if (!target) return;
      setActiveView(target);
    });
  });

  document.querySelectorAll('[data-tool-id]').forEach((node) => {
    node.addEventListener('click', () => {
      const toolId = node.getAttribute('data-tool-id');
      const tool = lilithTools.find((item) => item.id === toolId);
      if (!tool) return;
      launchTool(tool);
    });
  });

  edgeOpenButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const target = button.getAttribute('data-edge-open');
      if (!target) return;
      const alreadyActive = appViews.some((view) => view.getAttribute('data-view') === target && view.classList.contains('is-active'));
      setActiveView(alreadyActive ? 'home' : target);
      appendEnvironmentLog(alreadyActive ? 'Returned to environment' : `Opened ${target}`);
    });
  });

  environmentObjects.forEach((node) => {
    node.addEventListener('click', () => {
      const targetView = node.getAttribute('data-env-target');
      const toolId = node.getAttribute('data-tool-id');
      if (toolId) {
        const tool = lilithTools.find((item) => item.id === toolId);
        if (tool) {
          launchTool(tool);
          appendEnvironmentLog(`Tool launched: ${tool.title}`);
        }
        return;
      }
      if (targetView) {
        setActiveView(targetView);
        appendEnvironmentLog(`Zone opened: ${targetView}`);
      }
    });
  });

  edgeToolChips.forEach((chip) => {
    chip.addEventListener('dragstart', (event) => {
      event.dataTransfer?.setData('text/lilith-tool-id', chip.getAttribute('data-tool-id') || '');
      chip.classList.add('dragging');
    });
    chip.addEventListener('dragend', () => chip.classList.remove('dragging'));
  });

  environmentDropzone?.addEventListener('dragover', (event) => {
    event.preventDefault();
    environmentDropzone.classList.add('drag-over');
  });
  environmentDropzone?.addEventListener('dragleave', () => {
    environmentDropzone.classList.remove('drag-over');
  });
  environmentDropzone?.addEventListener('drop', (event) => {
    event.preventDefault();
    environmentDropzone.classList.remove('drag-over');
    const toolId = event.dataTransfer?.getData('text/lilith-tool-id');
    if (!toolId) return;
    const tool = lilithTools.find((item) => item.id === toolId);
    if (!tool) return;
    launchTool(tool);
    appendEnvironmentLog(`Dropped and opened ${tool.title}`);
    showToast(`${tool.title} opened`);
  });

  osAiForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    const raw = (osAiInput?.value || '').trim();
    if (!raw) return;
    const text = raw.toLowerCase();

    const openView = (name) => {
      setActiveView(name);
      appendEnvironmentLog(`AI opened ${name}`);
      showToast(`Opened ${name}`);
    };

    if (text.includes('close') || text.includes('environment')) {
      setActiveView('home');
      appendEnvironmentLog('AI returned to environment');
      showToast('Environment focus');
    } else if (text.includes('message') || text.includes('inbox') || text.includes('friend')) {
      openView('messages');
    } else if (text.includes('social') || text.includes('feed')) {
      openView('social');
    } else if (text.includes('tool')) {
      openView('tools');
    } else if (text.includes('profile')) {
      openView('profile');
    } else if (text.includes('activity') || text.includes('notification')) {
      openView('activity');
    } else if (text.includes('pdf')) {
      launchTool(lilithTools.find((item) => item.id === 'pdf_editor') || lilithTools[0]);
      appendEnvironmentLog('AI launched PDF Editor');
    } else if (text.includes('reel')) {
      launchTool(lilithTools.find((item) => item.id === 'long_to_reels') || lilithTools[0]);
      appendEnvironmentLog('AI launched Reels Generator');
    } else if (text.includes('video')) {
      launchTool(lilithTools.find((item) => item.id === 'video_editor') || lilithTools[0]);
      appendEnvironmentLog('AI launched Video Editor');
    } else if (text.includes('call')) {
      homeStartCallBtn?.click();
      appendEnvironmentLog('AI initiated call flow');
    } else if (text.includes('post') || text.includes('share')) {
      openComposer();
      appendEnvironmentLog('AI opened post composer');
    } else {
      chatInput.value = raw;
      setActiveView('chat');
      chatForm?.dispatchEvent(new Event('submit'));
      appendEnvironmentLog('AI sent prompt to chat');
    }
    if (osAiInput) osAiInput.value = '';
  });

  openPostComposerBtn?.addEventListener('click', () => openComposer());
  homeNewPostBtn?.addEventListener('click', () => openComposer());
  closePostComposerBtn?.addEventListener('click', () => closeComposer());
  composerModal?.addEventListener('click', (event) => {
    if (event.target === composerModal) closeComposer();
  });
  closeCommentsModalBtn?.addEventListener('click', () => closeComments());
  commentsModal?.addEventListener('click', (event) => {
    if (event.target === commentsModal) closeComments();
  });
  postCommentBtn?.addEventListener('click', () => {
    const text = (commentInput?.value || '').trim();
    if (!text || !activeCommentsPostId) return;
    const post = socialState.posts.find((item) => item.id === activeCommentsPostId);
    if (!post) return;
    post.comments.push({ by: '@lilith.user', text });
    commentInput.value = '';
    openComments(activeCommentsPostId);
    renderSocialFeed();
    showToast('Comment posted');
  });
  submitPostBtn?.addEventListener('click', () => {
    const caption = (postCaptionInput?.value || '').trim();
    if (!caption) {
      postStatus.textContent = 'Add a caption before posting.';
      return;
    }
    const mediaName = postMediaInput?.files?.[0]?.name || '';
    const newPost = {
      id: `post-${Date.now()}`,
      author: '@lilith.user',
      name: 'Lilith User',
      text: mediaName ? `${caption} (attached: ${mediaName})` : caption,
      likes: 0,
      comments: [],
      saves: 0,
      type: mediaName ? 'media' : 'text',
      media: '',
      timestamp: 'now',
      active: true,
      audience: postAudienceSelect?.value || 'Public',
    };
    socialState.posts.unshift(newPost);
    postStatus.textContent = 'Posted successfully.';
    postCaptionInput.value = '';
    if (postMediaInput) postMediaInput.value = '';
    renderSocialFeed();
    renderHomeHighlights();
    if (profilePostCount) profilePostCount.textContent = `${Number(profilePostCount.textContent || 0) + 1}`;
    closeComposer();
    showToast('Post published');
  });

  document.getElementById('messages-search')?.addEventListener('input', (event) => {
    renderThreads(event.target.value || '');
  });
  threadForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    const text = (threadInput?.value || '').trim();
    if (!text) return;
    const thread = getCurrentThread();
    const nowLabel = new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
    thread.messages.push({ from: 'me', text, ts: nowLabel, read: false });
    threadInput.value = '';
    renderThreadPreview();
    showToast('Message sent');
    if (threadTyping) {
      threadTyping.classList.remove('hidden');
      setTimeout(() => {
        threadTyping.classList.add('hidden');
        const replyLabel = new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
        thread.messages.push({ from: 'them', text: 'Received. I will reply shortly.', ts: replyLabel, read: true });
        thread.unread += 1;
        renderThreadPreview();
        renderThreads();
      }, 1100);
    }
  });
  threadCallBtn?.addEventListener('click', () => {
    const thread = getCurrentThread();
    if (metricCalls) metricCalls.textContent = `${Number(metricCalls.textContent || 0) + 1}`;
    showToast(`Calling ${thread.username}...`);
  });
  threadAttachBtn?.addEventListener('click', () => {
    showToast('Attachment flow ready');
  });
  discoverSearch?.addEventListener('input', (event) => renderDiscover(event.target.value || ''));
  homeStartCallBtn?.addEventListener('click', () => {
    if (metricCalls) metricCalls.textContent = `${Number(metricCalls.textContent || 0) + 1}`;
    showToast('Call flow opened');
  });
  profileMessageBtn?.addEventListener('click', () => {
    setActiveView('messages');
    showToast('Messaging from profile');
  });
  profileCallBtn?.addEventListener('click', () => {
    if (metricCalls) metricCalls.textContent = `${Number(metricCalls.textContent || 0) + 1}`;
    showToast('Call started from profile');
  });
  profileFollowBtn?.addEventListener('click', () => {
    const current = Number(profileFollowerCount?.textContent || 0);
    if (profileFollowerCount) profileFollowerCount.textContent = `${current + 1}`;
    showToast('Connected');
  });
  profileTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const target = tab.getAttribute('data-profile-tab');
      profileTabs.forEach((node) => node.classList.toggle('active', node === tab));
      if (!profileTabContent) return;
      if (target === 'posts') {
        profileTabContent.innerHTML = socialState.posts.slice(0, 3).map((post) => `<p><strong>${post.timestamp}</strong> · ${post.text}</p>`).join('');
      } else if (target === 'media') {
        profileTabContent.innerHTML = '<p>Media grid ready. Uploads and reels appear here.</p>';
      } else if (target === 'activity') {
        profileTabContent.innerHTML = '<p>Recent comments, follows, and reactions appear here.</p>';
      } else {
        profileTabContent.innerHTML = '<p>Favorite tools: PDF Editor, Reels Generator, Screenshot Analyzer.</p>';
      }
    });
  });

  function appendLog(text) {
    if (!logList) return;
    const li = document.createElement('li');
    const now = new Date().toLocaleTimeString();
    li.textContent = `[${now}] ${text}`;
    logList.prepend(li);
  }

  function appendEnvironmentLog(text) {
    if (!environmentOverlayLog) return;
    const now = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const line = document.createElement('p');
    line.textContent = `${now} · ${text}`;
    environmentOverlayLog.prepend(line);
    while (environmentOverlayLog.children.length > 10) {
      environmentOverlayLog.removeChild(environmentOverlayLog.lastElementChild);
    }
  }

  function showToast(message) {
    if (!toastNode) return;
    toastNode.textContent = message;
    toastNode.classList.remove('hidden');
    clearTimeout(showToast._timer);
    showToast._timer = setTimeout(() => toastNode.classList.add('hidden'), 1800);
  }

  function setActiveView(viewName) {
    appViews.forEach((node) => {
      node.classList.toggle('is-active', node.getAttribute('data-view') === viewName);
      if (node.id === 'toolbox') {
        const shouldShow = node.classList.contains('is-active');
        node.classList.toggle('hidden', !shouldShow);
      }
    });
    navButtons.forEach((button) => {
      button.classList.toggle('active', button.getAttribute('data-view-target') === viewName);
    });
  }

  let swipeStartX = 0;
  let swipeStartY = 0;
  let swipeActive = false;
  function beginSwipe(x, y, target) {
    if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;
    swipeStartX = x;
    swipeStartY = y;
    swipeActive = true;
  }
  function endSwipe(x, y) {
    if (!swipeActive) return;
    swipeActive = false;
    const dx = x - swipeStartX;
    const dy = y - swipeStartY;
    const nearLeft = swipeStartX <= 24;
    const nearRight = swipeStartX >= (window.innerWidth - 24);
    const nearTop = swipeStartY <= 24;
    const nearBottom = swipeStartY >= (window.innerHeight - 24);

    if (nearLeft && dx > 56) {
      setActiveView('messages');
      appendEnvironmentLog('Swipe: opened messages');
      return;
    }
    if (nearRight && dx < -56) {
      setActiveView('tools');
      appendEnvironmentLog('Swipe: opened tools');
      return;
    }
    if (nearTop && dy > 56) {
      setActiveView('chat');
      appendEnvironmentLog('Swipe: opened AI panel');
      return;
    }
    if (nearBottom && dy < -56) {
      setActiveView('activity');
      appendEnvironmentLog('Swipe: opened activity');
    }
  }

  window.addEventListener('touchstart', (event) => {
    const touch = event.changedTouches?.[0];
    if (!touch) return;
    beginSwipe(touch.clientX, touch.clientY, event.target);
  }, { passive: true });
  window.addEventListener('touchend', (event) => {
    const touch = event.changedTouches?.[0];
    if (!touch) return;
    endSwipe(touch.clientX, touch.clientY);
  }, { passive: true });
  window.addEventListener('mousedown', (event) => beginSwipe(event.clientX, event.clientY, event.target));
  window.addEventListener('mouseup', (event) => endSwipe(event.clientX, event.clientY));

  function renderSocialFeed() {
    if (!socialFeedList) return;
    socialFeedList.innerHTML = '';
    socialState.posts.forEach((post) => {
      const article = document.createElement('article');
      article.className = 'social-post';
      article.innerHTML = `
        <div class="social-meta">
          <div class="social-author">
            <img class="avatar-sm" src="assets/lilith_neutral.png" alt="${post.name}" />
            <div>
              <strong>${post.name}</strong>
              <p class="small">${post.author} · ${post.timestamp || 'now'} ${post.active ? '<span class="presence-dot online"></span>' : ''}</p>
            </div>
          </div>
          <span class="label">${post.type}</span>
        </div>
        <p>${post.text}</p>
        ${post.media ? `<img src="${post.media}" alt="post media" class="social-post-media" />` : ''}
        <div class="social-actions">
          <button class="secondary social-action-btn" data-action="like">Like ${post.likes}</button>
          <button class="secondary social-action-btn" data-action="comment">Comment ${post.comments.length}</button>
          <button class="secondary social-action-btn" data-action="share">Share</button>
          <button class="secondary social-action-btn" data-action="save">Save ${post.saves}</button>
          <button class="secondary social-action-btn" data-action="message">Message</button>
          <button class="secondary social-action-btn" data-action="call">Call</button>
        </div>
      `;
      article.querySelectorAll('[data-action]').forEach((button) => {
        button.addEventListener('click', () => {
          const action = button.getAttribute('data-action');
          if (action === 'like') {
            post.likes += 1;
            button.classList.add('liked');
          }
          if (action === 'comment') openComments(post.id);
          if (action === 'share') {
            button.classList.add('shared');
            showToast('Shared');
          }
          if (action === 'save') post.saves += 1;
          if (action === 'message') setActiveView('messages');
          if (action === 'call') showToast(`Calling ${post.author}...`);
          renderSocialFeed();
        });
      });
      article.querySelector('.social-author')?.addEventListener('click', () => {
        setActiveView('profile');
        showToast(`Opened ${post.author}`);
      });
      article.addEventListener('mousemove', (event) => {
        const rect = article.getBoundingClientRect();
        const ratio = ((event.clientY - rect.top) / rect.height - 0.5) * 1.2;
        article.style.transform = `translateY(${Math.round(ratio)}px)`;
      });
      article.addEventListener('mouseleave', () => {
        article.style.transform = '';
      });
      socialFeedList.appendChild(article);
    });
    socialFeedSkeleton?.classList.add('hidden');
    socialFeedList.classList.remove('hidden');
    socialFeedSentinel?.classList.remove('hidden');
  }

  function loadMoreFeedPosts() {
    const source = extraFeedSeed[feedLoadIndex % extraFeedSeed.length];
    feedLoadIndex += 1;
    socialState.posts.push({
      id: `auto-${Date.now()}-${feedLoadIndex}`,
      author: '@discover',
      name: 'Discover',
      text: source,
      likes: 8 + feedLoadIndex,
      comments: [{ by: '@ava', text: 'Nice flow.' }],
      saves: 4,
      type: 'text',
      timestamp: 'now',
      active: feedLoadIndex % 2 === 0,
    });
    renderSocialFeed();
  }

  function renderHomeHighlights() {
    if (!homeSocialList) return;
    homeSocialList.innerHTML = '';
    socialState.posts.slice(0, 3).forEach((post) => {
      const li = document.createElement('li');
      li.textContent = `${post.author}: ${post.text}`;
      homeSocialList.appendChild(li);
    });
    homeSocialSkeleton?.classList.add('hidden');
    homeSocialList.classList.remove('hidden');
  }

  function getCurrentThread() {
    return socialState.threads.find((thread) => thread.id === socialState.currentThreadId) || socialState.threads[0];
  }

  function renderThreads(filter = '') {
    if (!messagesThreadList) return;
    messagesThreadList.innerHTML = '';
    socialState.threads
      .filter((thread) => `${thread.username} ${thread.name}`.toLowerCase().includes(filter.toLowerCase()))
      .forEach((thread) => {
        const li = document.createElement('li');
        const lastMessage = thread.messages[thread.messages.length - 1];
        li.innerHTML = `
          <div class="thread-row">
            <img class="avatar-sm" src="assets/lilith_smirk.png" alt="${thread.name}" />
            <div class="thread-meta">
              <div><strong>${thread.name}</strong> <span class="small">${thread.username}</span> ${thread.active ? '<span class="presence-dot online"></span>' : ''}</div>
              <p class="thread-preview-text">${lastMessage?.text || 'No messages yet'}</p>
            </div>
            <div>
              <p class="small">${lastMessage?.ts || ''}</p>
              ${thread.unread ? `<span class="unread-pill">${thread.unread}</span>` : ''}
            </div>
          </div>
        `;
        li.addEventListener('click', () => {
          socialState.currentThreadId = thread.id;
          renderThreadPreview();
        });
        messagesThreadList.appendChild(li);
      });
  }

  function renderThreadPreview() {
    const thread = getCurrentThread();
    if (!thread || !threadPreview || !threadTitle) return;
    threadTitle.textContent = thread.username;
    threadPreview.innerHTML = '';
    thread.messages.forEach((message) => {
      const bubble = document.createElement('div');
      bubble.className = `thread-bubble ${message.from === 'me' ? 'mine' : 'theirs'}`;
      bubble.textContent = message.text;
      threadPreview.appendChild(bubble);
      const timestamp = document.createElement('p');
      timestamp.className = 'thread-timestamp';
      timestamp.textContent = `${message.ts || ''}${message.from === 'me' && message.read ? ' · Read' : ''}`;
      threadPreview.appendChild(timestamp);
    });
    thread.unread = 0;
    const unreadTotal = socialState.threads.reduce((sum, item) => sum + item.unread, 0);
    if (metricUnread) metricUnread.textContent = `${unreadTotal}`;
    threadPreview.scrollTop = threadPreview.scrollHeight;
  }

  function renderDiscover(query = '') {
    if (!discoverResults) return;
    discoverResults.innerHTML = '';
    socialState.discover
      .filter((person) => `${person.username} ${person.name}`.toLowerCase().includes(query.toLowerCase()))
      .forEach((person) => {
        const li = document.createElement('li');
        li.innerHTML = `${person.name} <span class="label">${person.username}</span>`;
        const actions = document.createElement('div');
        actions.className = 'social-actions';
        const messageBtn = document.createElement('button');
        messageBtn.className = 'secondary';
        messageBtn.textContent = 'Message';
        messageBtn.addEventListener('click', () => {
          setActiveView('messages');
          showToast(`Opened thread with ${person.username}`);
        });
        const followBtn = document.createElement('button');
        followBtn.className = 'secondary';
        followBtn.textContent = 'Follow';
        followBtn.addEventListener('click', () => showToast(`Following ${person.username}`));
        actions.append(messageBtn, followBtn);
        li.appendChild(actions);
        discoverResults.appendChild(li);
      });
  }

  function renderNotifications() {
    if (!notificationsList || !notificationsEmpty) return;
    notificationsList.innerHTML = '';
    if (osNotificationCount) osNotificationCount.textContent = `${socialState.notifications.length}`;
    if (!socialState.notifications.length) {
      notificationsEmpty.classList.remove('hidden');
      notificationsList.classList.add('hidden');
      return;
    }
    notificationsEmpty.classList.add('hidden');
    notificationsList.classList.remove('hidden');
    socialState.notifications.forEach((item) => {
      const li = document.createElement('li');
      li.textContent = item;
      notificationsList.appendChild(li);
    });
  }

  function openComments(postId) {
    const post = socialState.posts.find((item) => item.id === postId);
    if (!post || !commentsModal || !commentsList) return;
    activeCommentsPostId = postId;
    commentsList.innerHTML = '';
    post.comments.forEach((entry) => {
      const li = document.createElement('li');
      li.innerHTML = `<strong>${entry.by}</strong> ${entry.text}`;
      commentsList.appendChild(li);
    });
    commentsModal.classList.remove('hidden');
    commentsModal.setAttribute('aria-hidden', 'false');
    commentInput?.focus();
  }

  function closeComments() {
    commentsModal?.classList.add('hidden');
    commentsModal?.setAttribute('aria-hidden', 'true');
    activeCommentsPostId = null;
  }

  function openComposer() {
    if (!composerModal) return;
    composerModal.classList.remove('hidden');
    composerModal.setAttribute('aria-hidden', 'false');
    postCaptionInput?.focus();
  }

  function closeComposer() {
    if (!composerModal) return;
    composerModal.classList.add('hidden');
    composerModal.setAttribute('aria-hidden', 'true');
  }

  function downloadBlob(blob, filename) {
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
  }

  async function loadPdfJs() {
    if (pdfJsApi) return pdfJsApi;
    try {
      const module = await import('https://cdn.jsdelivr.net/npm/pdfjs-dist@4.5.136/build/pdf.min.mjs');
      module.GlobalWorkerOptions.workerSrc = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@4.5.136/build/pdf.worker.min.mjs';
      pdfJsApi = module;
      return pdfJsApi;
    } catch (error) {
      appendLog(`PDF engine unavailable: ${error.message}`);
      return null;
    }
  }

  async function ensureTesseractWorker() {
    if (tesseractWorker) return tesseractWorker;
    const module = await import('https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/+esm');
    tesseractWorker = await module.createWorker('eng');
    return tesseractWorker;
  }

  function formatSeconds(value) {
    const total = Math.max(0, Math.floor(Number(value) || 0));
    const minutes = Math.floor(total / 60);
    const seconds = total % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  }

  function arrayBufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const chunkSize = 0x8000;
    for (let index = 0; index < bytes.length; index += chunkSize) {
      const chunk = bytes.subarray(index, index + chunkSize);
      binary += String.fromCharCode(...chunk);
    }
    return btoa(binary);
  }

  function setWorkspacePrimaryAction(toolId) {
    if (!workspacePrimaryButton) return;
    workspacePrimaryButton.onclick = null;
    workspacePrimaryButton.textContent = toolId === 'pdf_editor' ? 'Export' : 'Done';

    if (toolId === 'pdf_editor') {
      workspacePrimaryButton.textContent = 'Export';
      workspacePrimaryButton.onclick = async () => {
        if (!pdfState.file) {
          appendLog('Load a PDF before exporting');
          return;
        }
        try {
          const payload = {
            filename: pdfState.file.name,
            base64: arrayBufferToBase64(pdfState.dataBuffer),
            annotations: pdfState.annotations,
            removedPages: Array.from(pdfState.removedPages),
            addedPages: pdfState.addedPages,
          };
          const json = await callBackend('/api/pdf/export', payload);
          const binary = atob(json.base64 || '');
          const bytes = new Uint8Array(binary.length);
          for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
          const blob = new Blob([bytes], { type: 'application/pdf' });
          downloadBlob(blob, `${(pdfState.file.name || 'lilith').replace(/\.pdf$/i, '')}-edited.pdf`);
          appendLog('PDF exported');
        } catch (error) {
          appendLog(`PDF export failed: ${error.message}`);
        }
      };
    } else if (toolId === 'video_editor') {
      workspacePrimaryButton.textContent = 'Export';
      workspacePrimaryButton.onclick = async () => {
        const clip = videoClips.find((item) => item.id === selectedClipId);
        if (!clip) {
          appendLog('Select a clip before export');
          return;
        }
        try {
          await exportClipRange(clip, 'lilith-video');
          appendLog('Video export completed');
        } catch (error) {
          appendLog(`Video export failed: ${error.message}`);
        }
      };
    } else if (toolId === 'long_to_reels') {
      workspacePrimaryButton.textContent = 'Export';
      workspacePrimaryButton.onclick = async () => {
        const clips = reelsState.clips.filter((clip) => reelsState.selected.has(clip.id));
        if (!clips.length) {
          appendLog('Select at least one reel');
          return;
        }
        for (const clip of clips) {
          try {
            await exportClipRange(clip, 'lilith-reel');
          } catch (error) {
            appendLog(`Reel export failed: ${error.message}`);
          }
        }
        appendLog(`Reels exported (${clips.length})`);
      };
    } else {
      workspacePrimaryButton.textContent = 'Done';
      workspacePrimaryButton.onclick = () => closeToolWorkspace();
    }
  }

  function openToolWorkspace(toolId) {
    if (!workspaceModal || !workspaceToolIds.has(toolId)) return;
    setActiveView('tools');
    activeWorkspace = toolId;
    Object.entries(workspaceViews).forEach(([id, view]) => {
      if (!view) return;
      view.classList.toggle('hidden', id !== toolId);
    });
    if (workspaceTitle) workspaceTitle.textContent = workspaceTitles[toolId] || 'Tool Workspace';
    setWorkspacePrimaryAction(toolId);
    workspaceModal.classList.remove('hidden');
    workspaceModal.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';

    if (toolId === 'pdf_editor') renderPdfWorkspace();
    if (toolId === 'video_editor') renderVideoEditorWorkspace();
    if (toolId === 'long_to_reels') renderReelsWorkspace();
    showToast('Power mode activated');
  }

  function closeToolWorkspace() {
    if (!workspaceModal) return;
    workspaceModal.classList.add('hidden');
    workspaceModal.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
    activeWorkspace = null;
  }

  function renderPdfWorkspace() {
    const pageList = document.getElementById('pdf-page-list');
    const canvas = document.getElementById('pdf-page-canvas');
    const zoomLabel = document.getElementById('pdf-zoom-label');
    if (!pageList || !canvas || !zoomLabel) return;

    pageList.innerHTML = '';
    pdfPages.forEach((pageObj) => {
      const li = document.createElement('li');
      li.textContent = `Page ${pageObj.page}`;
      if (pageObj.page === activePdfPage) li.classList.add('active');
      li.addEventListener('click', () => {
        activePdfPage = pageObj.page;
        renderPdfWorkspace();
      });
      pageList.appendChild(li);
    });

    const currentPage = pdfPages.find((item) => item.page === activePdfPage);
    canvas.style.transform = '';
    canvas.style.transformOrigin = '';
    if (!currentPage) {
      canvas.textContent = 'Open a PDF to start editing.';
      zoomLabel.textContent = `${pdfZoom}%`;
      return;
    }

    canvas.innerHTML = '';
    const viewportWidth = Math.min(900, Math.max(420, canvas.clientWidth || 680));
    const placeholder = document.createElement('div');
    placeholder.className = 'small';
    placeholder.textContent = 'Rendering page...';
    canvas.appendChild(placeholder);

    const drawAnnotationLayer = () => {
      const layer = document.createElement('div');
      layer.style.position = 'absolute';
      layer.style.inset = '0';
      layer.style.pointerEvents = 'none';
      layer.style.borderRadius = '10px';

      const pageAnnotations = pdfState.annotations.filter((item) => item.page === activePdfPage);
      pageAnnotations.forEach((note) => {
        const badge = document.createElement('div');
        badge.textContent = `${note.tool}: ${note.text || 'annotation'}`;
        badge.style.position = 'relative';
        badge.style.margin = '6px';
        badge.style.padding = '4px 8px';
        badge.style.background = 'rgba(255, 239, 129, 0.5)';
        badge.style.color = '#121212';
        badge.style.borderRadius = '8px';
        badge.style.fontSize = '12px';
        layer.appendChild(badge);
      });
      return layer;
    };

    const renderNative = async () => {
      const api = await loadPdfJs();
      if (!api || !pdfState.dataBuffer) {
        canvas.textContent = currentPage.previewText || 'PDF ready.';
        return;
      }
      try {
        const doc = pdfState.pdfDoc || await api.getDocument({ data: pdfState.dataBuffer }).promise;
        pdfState.pdfDoc = doc;
        const page = await doc.getPage(activePdfPage);
        const viewport = page.getViewport({ scale: (pdfZoom / 100) * (viewportWidth / page.getViewport({ scale: 1 }).width) });
        const pdfCanvas = document.createElement('canvas');
        pdfCanvas.width = Math.floor(viewport.width);
        pdfCanvas.height = Math.floor(viewport.height);
        pdfCanvas.style.width = `${Math.floor(viewport.width)}px`;
        pdfCanvas.style.height = `${Math.floor(viewport.height)}px`;
        pdfCanvas.style.borderRadius = '10px';
        pdfCanvas.style.display = 'block';
        pdfCanvas.style.margin = '0 auto';
        await page.render({ canvasContext: pdfCanvas.getContext('2d'), viewport }).promise;
        canvas.innerHTML = '';
        const wrapper = document.createElement('div');
        wrapper.style.position = 'relative';
        wrapper.style.width = `${Math.floor(viewport.width)}px`;
        wrapper.style.margin = '0 auto';
        wrapper.appendChild(pdfCanvas);
        wrapper.appendChild(drawAnnotationLayer());
        canvas.appendChild(wrapper);
      } catch (error) {
        canvas.textContent = currentPage.previewText || `Unable to render page: ${error.message}`;
      }
    };

    renderNative();
    zoomLabel.textContent = `${pdfZoom}%`;

    document.querySelectorAll('[data-pdf-tool]').forEach((button) => {
      const isActive = button.getAttribute('data-pdf-tool') === activePdfTool;
      button.classList.toggle('active', isActive);
    });
  }

  function renderVideoEditorWorkspace() {
    const track = document.getElementById('video-timeline-track');
    const label = document.getElementById('video-playhead-label');
    const previewSurface = document.querySelector('.video-preview-surface');
    if (!track || !label) return;

    const currentSeconds = (videoPlayhead / 100) * (videoState.duration || 0);
    label.textContent = `Playhead ${formatSeconds(currentSeconds)}`;
    track.innerHTML = '';

    if (previewSurface && !videoPlayerNode) {
      const node = document.createElement('video');
      node.id = 'video-preview-player';
      node.controls = true;
      node.style.width = 'min(720px, 100%)';
      node.style.maxHeight = '260px';
      node.style.borderRadius = '12px';
      node.style.border = '1px solid rgba(255,255,255,0.12)';
      node.style.background = '#05070a';
      previewSurface.innerHTML = '';
      previewSurface.appendChild(node);
      const cap = document.createElement('p');
      cap.id = 'video-preview-caption';
      cap.className = 'small';
      cap.textContent = 'Load a video to begin editing.';
      previewSurface.appendChild(cap);
      videoPlayerNode = node;
      if (videoState.objectUrl) {
        videoPlayerNode.src = videoState.objectUrl;
      }
    }

    videoClips.forEach((clip) => {
      const clipNode = document.createElement('button');
      clipNode.type = 'button';
      clipNode.className = 'timeline-clip' + (clip.id === selectedClipId ? ' active' : '');
      clipNode.draggable = true;
      clipNode.innerHTML = `<strong>${clip.title}</strong><p class="small">${formatSeconds(clip.start)} - ${formatSeconds(clip.end)}</p>`;
      clipNode.addEventListener('click', () => {
        selectedClipId = clip.id;
        renderVideoEditorWorkspace();
      });
      clipNode.addEventListener('dragstart', (event) => {
        event.dataTransfer?.setData('text/plain', clip.id);
      });
      clipNode.addEventListener('dragover', (event) => event.preventDefault());
      clipNode.addEventListener('drop', (event) => {
        event.preventDefault();
        const draggedId = event.dataTransfer?.getData('text/plain');
        if (!draggedId || draggedId === clip.id) return;
        const fromIndex = videoClips.findIndex((item) => item.id === draggedId);
        const toIndex = videoClips.findIndex((item) => item.id === clip.id);
        if (fromIndex < 0 || toIndex < 0) return;
        const [moved] = videoClips.splice(fromIndex, 1);
        videoClips.splice(toIndex, 0, moved);
        renderVideoEditorWorkspace();
      });
      track.appendChild(clipNode);
    });

    const activeClip = videoClips.find((clip) => clip.id === selectedClipId) || videoClips[0];
    const caption = document.getElementById('video-preview-caption');
    if (activeClip && videoPlayerNode) {
      if (caption) caption.textContent = `Editing "${activeClip.title}" • ${formatSeconds(activeClip.end - activeClip.start)}`;
      const playheadSeconds = (videoPlayhead / 100) * (videoState.duration || 0);
      if (!Number.isNaN(playheadSeconds) && Number.isFinite(playheadSeconds) && videoPlayerNode.readyState >= 1) {
        try {
          videoPlayerNode.currentTime = Math.min(Math.max(playheadSeconds, 0), (videoState.duration || 0));
        } catch (_) {}
      }
    }
  }

  function renderReelsWorkspace() {
    const grid = document.getElementById('reels-clips-grid');
    if (!grid) return;
    grid.innerHTML = '';

    reelsState.clips.forEach((clip) => {
      const card = document.createElement('article');
      card.className = 'workspace-card' + (reelsState.selected.has(clip.id) ? ' selected' : '');
      card.innerHTML = `
        <img src="assets/lilith_smirk.png" alt="Clip preview" />
        <strong>${clip.title}</strong>
        <p class="small">${formatSeconds(clip.start)} - ${formatSeconds(clip.end)} (${formatSeconds(clip.end - clip.start)})</p>
      `;
      const row = document.createElement('div');
      row.className = 'stack two-col';
      const playBtn = document.createElement('button');
      playBtn.type = 'button';
      playBtn.className = 'secondary';
      playBtn.textContent = 'Play';
      playBtn.addEventListener('click', () => {
        if (!videoPlayerNode || !videoState.duration) {
          appendLog(`Preview unavailable for ${clip.title}: load source video first`);
          return;
        }
        openToolWorkspace('video_editor');
        const matched = videoClips.find((item) => item.id === clip.id);
        if (matched) selectedClipId = matched.id;
        videoPlayerNode.currentTime = clip.start;
        videoPlayerNode.play().catch(() => {});
        appendLog(`Preview reel clip: ${clip.title}`);
      });
      const selectBtn = document.createElement('button');
      selectBtn.type = 'button';
      selectBtn.className = 'primary';
      selectBtn.textContent = reelsState.selected.has(clip.id) ? 'Selected' : 'Select';
      selectBtn.addEventListener('click', () => {
        if (reelsState.selected.has(clip.id)) reelsState.selected.delete(clip.id);
        else reelsState.selected.add(clip.id);
        renderReelsWorkspace();
      });
      row.append(playBtn, selectBtn);
      card.appendChild(row);
      grid.appendChild(card);
    });
  }

  function toolRouteStatus(tool) {
    return document.getElementById(tool.targetId) ? 'active' : 'missing';
  }

  function launchTool(tool) {
    const target = document.getElementById(tool.targetId);
    if (!target) {
      appendLog(`Route missing for ${tool.title} (${tool.route})`);
      console.error(`[Lilith Tools] Missing route target: ${tool.targetId} for ${tool.title}`);
      return;
    }
    window.location.hash = tool.route;
    if (workspaceToolIds.has(tool.id)) {
      openToolWorkspace(tool.id);
      appendLog(`Opened ${tool.title} workspace`);
      return;
    }
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    appendLog(`Opened ${tool.title}`);
  }

  function renderToolsHub() {
    if (!toolsCatalog) return;
    toolsCatalog.innerHTML = '';
    const searchText = (toolsSearch?.value || '').trim().toLowerCase();
    const filteredTools = lilithTools.filter((tool) => {
      if (!searchText) return true;
      return `${tool.title} ${tool.category} ${tool.note || ''}`.toLowerCase().includes(searchText);
    });

    filteredTools.forEach((tool) => {
      const status = toolRouteStatus(tool);
      const card = document.createElement('div');
      card.className = 'tool-card';
      card.innerHTML = `
        <div class="status-row">
          <span class="pill">${tool.category}</span>
          <span class="${status === 'active' ? 'tool-status-ok' : 'tool-status-missing'}">${status}</span>
        </div>
        <p class="title">${tool.title}</p>
        <p class="small">${tool.note || `Route: ${tool.route}`}</p>
      `;

      const button = document.createElement('button');
      button.className = 'primary full';
      button.type = 'button';
      button.textContent = 'Launch';
      button.addEventListener('click', () => launchTool(tool));
      card.appendChild(button);
      toolsCatalog.appendChild(card);
    });
  }

  function renderToolsDebugInventory() {
    const debugEnabled = window.location.search.includes('debug_tools=1') || localStorage.getItem('lilithDebugTools') === 'true';
    if (!debugEnabled || !toolsDebugPanel || !toolsDebugOutput) return;
    toolsDebugPanel.style.display = '';

    const inventory = lilithTools.map((tool) => ({
      id: tool.id,
      title: tool.title,
      category: tool.category,
      route: tool.route,
      targetId: tool.targetId,
      status: toolRouteStatus(tool)
    }));
    toolsDebugOutput.textContent = JSON.stringify({
      registeredTools: inventory.length,
      routesChecked: inventory.map((i) => i.route),
      active: inventory.filter((i) => i.status === 'active').map((i) => i.id),
      missing: inventory.filter((i) => i.status === 'missing').map((i) => i.id),
      inventory
    }, null, 2);
  }

  toolsSearch?.addEventListener('input', () => renderToolsHub());

  workspaceBackButton?.addEventListener('click', () => closeToolWorkspace());
  workspaceModal?.addEventListener('click', (event) => {
    if (event.target === workspaceModal) closeToolWorkspace();
  });

  document.querySelectorAll('[data-pdf-tool]').forEach((button) => {
    button.addEventListener('click', () => {
      activePdfTool = button.getAttribute('data-pdf-tool') || 'select';
      const annotationInput = document.getElementById('pdf-annotation-input');
      if (annotationInput && annotationInput.value.trim()) {
        const note = {
          page: activePdfPage,
          tool: activePdfTool,
          text: annotationInput.value.trim(),
          createdAt: new Date().toISOString(),
        };
        pdfState.annotations.push(note);
        pdfHistory.push(`${activePdfTool}: ${annotationInput.value.trim()}`);
        pdfHistoryPointer = pdfHistory.length - 1;
        annotationInput.value = '';
      }
      renderPdfWorkspace();
    });
  });

  document.getElementById('pdf-upload-btn')?.addEventListener('click', async () => {
    const picker = document.createElement('input');
    picker.type = 'file';
    picker.accept = 'application/pdf';
    picker.addEventListener('change', async () => {
      const file = picker.files?.[0];
      if (!file) return;
      pdfState.file = file;
      pdfState.dataBuffer = await file.arrayBuffer();
      pdfState.pdfDoc = null;
      pdfState.annotations = [];
      pdfState.removedPages = new Set();
      pdfState.addedPages = 0;
      try {
        const payload = await callBackend('/api/pdf/inspect', {
          filename: file.name,
          base64: arrayBufferToBase64(pdfState.dataBuffer),
        });
        const pages = Array.isArray(payload.pages) ? payload.pages : [];
        pdfPages.splice(0, pdfPages.length, ...pages.map((item, index) => ({ page: index + 1, previewText: item.previewText || `Page ${index + 1}` })));
        if (pdfPages.length === 0) {
          const fallbackCount = Number(payload.pageCount || 0);
          for (let index = 0; index < fallbackCount; index += 1) {
            pdfPages.push({ page: index + 1, previewText: `Page ${index + 1}` });
          }
        }
      } catch (error) {
        appendLog(`PDF inspect fallback: ${error.message}`);
        const fallbackCount = 1;
        pdfPages.splice(0, pdfPages.length, ...Array.from({ length: fallbackCount }).map((_, index) => ({ page: index + 1, previewText: `Page ${index + 1}` })));
      }
      activePdfPage = 1;
      renderPdfWorkspace();
      appendLog(`PDF loaded: ${file.name}`);
    });
    picker.click();
  });
  document.getElementById('pdf-zoom-in-btn')?.addEventListener('click', () => {
    pdfZoom = Math.min(200, pdfZoom + 10);
    renderPdfWorkspace();
  });
  document.getElementById('pdf-zoom-out-btn')?.addEventListener('click', () => {
    pdfZoom = Math.max(60, pdfZoom - 10);
    renderPdfWorkspace();
  });
  document.getElementById('pdf-add-page-btn')?.addEventListener('click', () => {
    const nextPage = pdfPages.length + 1;
    pdfPages.push({ page: nextPage, previewText: `Added page ${nextPage}` });
    pdfState.addedPages += 1;
    activePdfPage = nextPage;
    renderPdfWorkspace();
  });
  document.getElementById('pdf-remove-page-btn')?.addEventListener('click', () => {
    if (pdfPages.length <= 1) return;
    const index = pdfPages.findIndex((item) => item.page === activePdfPage);
    if (index >= 0) pdfPages.splice(index, 1);
    pdfState.removedPages.add(activePdfPage);
    pdfPages.forEach((item, idx) => { item.page = idx + 1; });
    activePdfPage = Math.min(activePdfPage, pdfPages.length);
    renderPdfWorkspace();
  });
  document.getElementById('pdf-undo-btn')?.addEventListener('click', () => {
    pdfHistoryPointer = Math.max(0, pdfHistoryPointer - 1);
    appendLog(`PDF undo -> ${pdfHistory[pdfHistoryPointer] || 'start'}`);
  });
  document.getElementById('pdf-redo-btn')?.addEventListener('click', () => {
    pdfHistoryPointer = Math.min(pdfHistory.length - 1, pdfHistoryPointer + 1);
    appendLog(`PDF redo -> ${pdfHistory[pdfHistoryPointer] || 'latest'}`);
  });

  document.getElementById('video-playhead-range')?.addEventListener('input', (event) => {
    videoPlayhead = Number(event.target.value || 0);
    renderVideoEditorWorkspace();
  });

  async function loadVideoIntoEditor(file) {
    if (!file) return false;
    if (videoState.objectUrl) URL.revokeObjectURL(videoState.objectUrl);
    videoState.objectUrl = URL.createObjectURL(file);
    videoState.sourceFile = file;
    if (videoPlayerNode) {
      videoPlayerNode.src = videoState.objectUrl;
      videoPlayerNode.load();
    }
    return new Promise((resolve) => {
      const probeVideo = document.createElement('video');
      probeVideo.preload = 'metadata';
      probeVideo.src = videoState.objectUrl;
      probeVideo.onloadedmetadata = () => {
        videoState.duration = Number(probeVideo.duration || 0);
        const fullDuration = Math.max(1, videoState.duration || 1);
        videoClips.splice(0, videoClips.length, {
          id: 'clip-1',
          title: file.name || 'Clip 1',
          start: 0,
          end: fullDuration,
        });
        selectedClipId = 'clip-1';
        videoPlayhead = 0;
        renderVideoEditorWorkspace();
        resolve(true);
      };
      probeVideo.onerror = () => resolve(false);
    });
  }

  async function exportClipRange(clip, filenamePrefix = 'lilith-clip') {
    if (!videoState.objectUrl || !clip) {
      throw new Error('No source video loaded');
    }
    const worker = document.createElement('video');
    worker.src = videoState.objectUrl;
    worker.muted = true;
    worker.crossOrigin = 'anonymous';
    await new Promise((resolve, reject) => {
      worker.onloadedmetadata = () => resolve();
      worker.onerror = () => reject(new Error('Unable to load source video'));
    });
    const stream = worker.captureStream ? worker.captureStream() : null;
    if (!stream || typeof MediaRecorder === 'undefined') {
      throw new Error('MediaRecorder export not supported in this browser');
    }
    const recorder = new MediaRecorder(stream, { mimeType: 'video/webm' });
    const chunks = [];
    recorder.ondataavailable = (event) => {
      if (event.data && event.data.size > 0) chunks.push(event.data);
    };
    const durationMs = Math.max(500, Math.floor((clip.end - clip.start) * 1000));
    await new Promise((resolve, reject) => {
      recorder.onstop = resolve;
      recorder.onerror = (event) => reject(event.error || new Error('Recorder failed'));
      worker.currentTime = clip.start;
      worker.play().catch(() => {});
      recorder.start(200);
      setTimeout(() => {
        worker.pause();
        recorder.stop();
      }, durationMs);
    });
    const blob = new Blob(chunks, { type: 'video/webm' });
    downloadBlob(blob, `${filenamePrefix}-${Date.now()}.webm`);
    return blob;
  }

  const reelsInputFile = document.getElementById('reels-video-input');
  reelsInputFile?.addEventListener('change', async () => {
    const file = reelsInputFile.files?.[0];
    if (!file) return;
    await loadVideoIntoEditor(file);
    appendLog(`Video source loaded: ${file.name}`);
  });
  const remixInputFile = document.getElementById('app-video-file');
  remixInputFile?.addEventListener('change', async () => {
    const file = remixInputFile.files?.[0];
    if (!file) return;
    await loadVideoIntoEditor(file);
    appendLog(`Video source loaded: ${file.name}`);
  });

  document.getElementById('video-trim-btn')?.addEventListener('click', () => {
    const clip = videoClips.find((item) => item.id === selectedClipId);
    if (!clip) return;
    clip.end = Math.max(clip.start + 1, clip.end - 1);
    renderVideoEditorWorkspace();
  });
  document.getElementById('video-split-btn')?.addEventListener('click', () => {
    const clip = videoClips.find((item) => item.id === selectedClipId);
    if (!clip || (clip.end - clip.start) < 2) return;
    const midpoint = (clip.start + clip.end) / 2;
    const originalEnd = clip.end;
    clip.end = midpoint;
    const newClip = { id: `clip-${Date.now()}`, title: `${clip.title} (Part 2)`, start: midpoint, end: originalEnd };
    const idx = videoClips.findIndex((item) => item.id === selectedClipId);
    videoClips.splice(idx + 1, 0, newClip);
    renderVideoEditorWorkspace();
  });
  document.getElementById('video-text-btn')?.addEventListener('click', () => appendLog('Video text overlay added'));
  document.getElementById('video-audio-btn')?.addEventListener('click', () => appendLog('Video audio track attached'));
  document.getElementById('video-effects-btn')?.addEventListener('click', () => appendLog('Video transition/effects added'));

  document.getElementById('reels-generate-btn')?.addEventListener('click', async () => {
    const inputFile = document.getElementById('reels-video-input')?.files?.[0];
    if (inputFile) {
      await loadVideoIntoEditor(inputFile);
    }
    const fileName = inputFile?.name;
    const urlValue = (document.getElementById('reels-source-url')?.value || '').trim();
    if (!inputFile && urlValue) {
      videoState.sourceUrl = urlValue;
      videoState.objectUrl = urlValue;
      if (videoPlayerNode) {
        videoPlayerNode.src = urlValue;
        videoPlayerNode.load();
      }
    }
    const source = fileName || urlValue || 'long_form_input.mp4';
    const duration = Math.max(30, Math.floor(videoState.duration || 90));
    const segmentLength = duration <= 60 ? 15 : 30;
    reelsState.clips = [];
    let cursor = 0;
    let counter = 1;
    while (cursor < duration) {
      const end = Math.min(duration, cursor + segmentLength);
      reelsState.clips.push({
        id: `${source}-segment-${counter}`,
        title: `Segment ${counter}`,
        start: cursor,
        end,
      });
      cursor = end;
      counter += 1;
    }
    reelsState.selected = new Set([reelsState.clips[0].id]);
    renderReelsWorkspace();
    appendLog('Auto-segmented long-form video into reels');
  });
  document.getElementById('reels-edit-btn')?.addEventListener('click', () => {
    if (reelsState.selected.size === 0) return;
    videoClips.splice(
      0,
      videoClips.length,
      ...reelsState.clips
        .filter((clip) => reelsState.selected.has(clip.id))
        .map((clip, idx) => ({ id: `reel-edit-${idx + 1}`, title: clip.title, start: clip.start, end: clip.end }))
    );
    selectedClipId = videoClips[0]?.id || selectedClipId;
    openToolWorkspace('video_editor');
    appendLog('Moved selected reels into Video Editor');
  });
  document.getElementById('reels-export-btn')?.addEventListener('click', async () => {
    const selected = reelsState.clips.filter((clip) => reelsState.selected.has(clip.id));
    if (!selected.length) return;
    for (const clip of selected) {
      try {
        await exportClipRange(clip, 'lilith-reel');
      } catch (error) {
        appendLog(`Reel export failed: ${error.message}`);
      }
    }
    appendLog(`Exported ${selected.length} reel(s)`);
  });

  const screenshotWorkspaceInput = document.getElementById('screenshot-workspace-input');
  const screenshotPreview = document.getElementById('screenshot-preview-image');
  const screenshotMeta = document.getElementById('screenshot-meta');
  const screenshotOutput = document.getElementById('screenshot-output');
  let screenshotImageDataUrl = '';
  screenshotWorkspaceInput?.addEventListener('change', () => {
    const file = screenshotWorkspaceInput.files?.[0];
    if (!file) return;
    screenshotMeta.textContent = `${file.name} • ${(file.size / 1024).toFixed(1)} KB`;
    const reader = new FileReader();
    reader.onload = () => {
      screenshotImageDataUrl = String(reader.result || '');
      screenshotPreview.src = screenshotImageDataUrl;
    };
    reader.readAsDataURL(file);
  });
  document.getElementById('screenshot-extract-btn')?.addEventListener('click', async () => {
    const file = screenshotWorkspaceInput?.files?.[0];
    if (!file) return;
    screenshotOutput.value = 'Extracting text with OCR...';
    try {
      const worker = await ensureTesseractWorker();
      const result = await worker.recognize(screenshotImageDataUrl || screenshotPreview.src);
      const extracted = (result?.data?.text || '').trim();
      const cleaned = extracted.replace(/\s+/g, ' ').slice(0, 1500);
      screenshotOutput.value = `Objective:\nConvert this screenshot into an implementation prompt.\n\nExtracted text:\n${cleaned || '[No readable text detected]'}\n\nStructured prompt:\nBuild a UI that preserves the original visual hierarchy, spacing rhythm, and CTA emphasis. Include responsive behavior and accessibility labels.`;
      appendLog('Screenshot OCR complete');
    } catch (error) {
      screenshotOutput.value = `OCR failed (${error.message}).\nFallback prompt:\nDescribe the visible layout, typography, and interaction cues from the image and recreate them in a modern responsive interface.`;
      appendLog('Screenshot OCR fallback used');
    }
  });
  document.getElementById('screenshot-copy-btn')?.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(screenshotOutput?.value || '');
      appendLog('Screenshot prompt copied');
    } catch (_) {}
  });

  const cloneWorkspaceUrl = document.getElementById('clone-workspace-url');
  const cloneFrame = document.getElementById('clone-preview-frame');
  const cloneStatus = document.getElementById('clone-status');
  const cloneStructureList = document.getElementById('clone-structure-list');
  document.getElementById('clone-workspace-fetch-btn')?.addEventListener('click', async () => {
    const url = (cloneWorkspaceUrl?.value || '').trim();
    if (!url) return;
    cloneStatus.textContent = 'Fetching...';
    try {
      const json = await callBackend('/api/clone/site', { url });
      const html = json.code || '<!doctype html><html><body><h1>Clone failed</h1></body></html>';
      lastClonedHtml = html;
      cloneFrame.srcdoc = html;
      cloneStatus.textContent = 'Ready';
      const tags = (json?.structure?.tags || []).slice(0, 20);
      cloneStructureList.innerHTML = '';
      tags.forEach((tag) => {
        const li = document.createElement('li');
        li.textContent = `<${tag.tag}> x${tag.count}`;
        cloneStructureList.appendChild(li);
      });
      appendLog('Website clone preview loaded');
      showToast('Clone ready');
    } catch (error) {
      cloneStatus.textContent = `Failed: ${error.message}`;
    }
  });
  document.getElementById('clone-export-btn')?.addEventListener('click', () => {
    const html = lastClonedHtml || '<!doctype html><html><body><h1>Lilith Clone Export</h1></body></html>';
    const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'lilith-clone-export.html';
    document.body.appendChild(link);
    link.click();
    link.remove();
  });

  const linkWorkspaceUrl = document.getElementById('link-workspace-url');
  const linkOutput = document.getElementById('link-output');
  document.getElementById('link-generate-btn')?.addEventListener('click', async () => {
    const url = (linkWorkspaceUrl?.value || '').trim();
    if (!url) return;
    linkOutput.value = 'Generating...';
    try {
      const result = await callBackend('/api/link/prompt', { url });
      linkOutput.value = `Source URL:\n${url}\n\nContent Summary:\nPrimary heading: ${result?.summary?.primaryHeading || 'N/A'}\nEstimated sections: ${result?.summary?.estimatedSections || 'N/A'}\nComponents: ${result?.summary?.components || 'N/A'}\n\nPrompt:\n${result?.prompt || ''}`;
      appendLog('Prompt from link generated');
      showToast('Prompt generated');
    } catch (error) {
      linkOutput.value = `Failed to generate prompt: ${error.message}`;
    }
  });
  document.getElementById('link-copy-btn')?.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(linkOutput?.value || '');
      appendLog('Link prompt copied');
    } catch (_) {}
  });

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

    const actions = document.createElement('div');
    actions.className = 'social-actions';
    const postBtn = document.createElement('button');
    postBtn.className = 'secondary social-action-btn';
    postBtn.type = 'button';
    postBtn.textContent = 'Post';
    postBtn.addEventListener('click', () => {
      socialState.posts.unshift({
        id: `tool-${Date.now()}`,
        author: '@lilith.user',
        name: 'Lilith User',
        text: `${title}: ${detail || 'Shared from tool output'}`,
        likes: 0,
        comments: [],
        saves: 0,
        type: type.toLowerCase(),
        media: mediaSrc || '',
        timestamp: 'now',
        active: true,
      });
      renderSocialFeed();
      renderHomeHighlights();
      showToast('Posted from tool');
      setActiveView('social');
    });
    const dmBtn = document.createElement('button');
    dmBtn.className = 'secondary social-action-btn';
    dmBtn.type = 'button';
    dmBtn.textContent = 'Message';
    dmBtn.addEventListener('click', () => {
      const thread = getCurrentThread();
      thread.messages.push({
        from: 'me',
        text: `${title}: ${detail || 'Shared from tool output'}`,
        ts: new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }),
        read: false,
      });
      renderThreadPreview();
      setActiveView('messages');
      showToast('Shared to message');
    });
    actions.append(postBtn, dmBtn);
    card.appendChild(actions);

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

  renderToolsHub();
  renderToolsDebugInventory();
  renderSocialFeed();
  renderHomeHighlights();
  renderThreads();
  renderThreadPreview();
  renderDiscover();
  renderNotifications();
  if (metricUnread) metricUnread.textContent = `${socialState.threads.reduce((sum, row) => sum + row.unread, 0)}`;
  if (metricCalls) metricCalls.textContent = metricCalls.textContent || '0';
  if (metricFollows) metricFollows.textContent = `${socialState.notifications.filter((entry) => entry.toLowerCase().includes('follow')).length}`;
  if (profilePostCount) profilePostCount.textContent = `${socialState.posts.length}`;
  if (profileFollowerCount) profileFollowerCount.textContent = '128';
  if (profileFollowingCount) profileFollowingCount.textContent = '84';
  setActiveView('home');
  profileTabs[0]?.click();

  if (socialFeedSentinel) {
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        loadMoreFeedPosts();
      }
    }, { rootMargin: '180px' });
    observer.observe(socialFeedSentinel);
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
      showToast('Reply ready');
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
      showToast('Image generated');
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
      const json = await callBackend('/api/code/review', { code: prompt, language: 'swift' });
      const suggestionLines = (json?.suggestions || []).map((item) => `- [${item.severity}] ${item.title}: ${item.detail}`);
      codeResp.textContent = suggestionLines.join('\n') || '// No review feedback';
      addToLibrary({
        type: 'Code',
        title: 'Code snippet',
        detail: (suggestionLines.join(' ') || '').slice(0, 220)
      });
      appendLog('Code assist ✓');
      showToast('Code analysis complete');
    } catch (err) {
      codeResp.textContent = '// Failed: ' + err.message;
      appendLog('Code assist failed');
    }
  });

  const pdfOpenButton = document.getElementById('app-pdf-open');
  const linkOpenButton = document.getElementById('app-link-open');
  const screenshotOpenButton = document.getElementById('app-screenshot-open');
  const videoEditorOpenButton = document.getElementById('app-video-editor-open');
  const reelsOpenButton = document.getElementById('app-reels-open');
  const cloneOpenButton = document.getElementById('app-clone-open');
  const pdfStatus = document.getElementById('app-pdf-status');
  const linkPromptForm = document.getElementById('app-link-prompt-form');
  const linkPromptUrl = document.getElementById('app-link-prompt-url');
  const linkPromptOutput = document.getElementById('app-link-prompt-output');
  const screenshotPromptForm = document.getElementById('app-screenshot-prompt-form');
  const screenshotFile = document.getElementById('app-screenshot-file');
  const screenshotStatus = document.getElementById('app-screenshot-status');
  const financeBalanceButton = document.getElementById('app-finance-balance');
  const financeAnalyzeButton = document.getElementById('app-finance-analyze');
  const financeOutput = document.getElementById('app-finance-output');
  const legalInput = document.getElementById('app-legal-input');
  const legalSummaryButton = document.getElementById('app-legal-summary');
  const legalClausesButton = document.getElementById('app-legal-clauses');
  const legalOutput = document.getElementById('app-legal-output');

  pdfOpenButton?.addEventListener('click', () => {
    openToolWorkspace('pdf_editor');
    pdfStatus.textContent = 'Document workspace opened.';
    appendLog('PDF editor opened');
  });
  linkOpenButton?.addEventListener('click', () => openToolWorkspace('prompt_from_link'));
  screenshotOpenButton?.addEventListener('click', () => openToolWorkspace('prompt_from_screenshot'));
  videoEditorOpenButton?.addEventListener('click', () => openToolWorkspace('video_editor'));
  reelsOpenButton?.addEventListener('click', () => openToolWorkspace('long_to_reels'));
  cloneOpenButton?.addEventListener('click', () => openToolWorkspace('website_clone'));

  linkPromptForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const url = (linkPromptUrl?.value || '').trim();
    if (!url) return;
    linkPromptOutput.textContent = 'Generating prompt…';
    appendLog(`Prompt from link → ${url}`);
    try {
      const json = await callBackend('/api/clone/site', { url });
      const prompt = `Use this cloned page as context and create a production prompt:\nURL: ${url}\nClone ID: ${json.id}\nFocus: structure, style, copy, and conversion goals.`;
      linkPromptOutput.textContent = prompt;
      addToLibrary({ type: 'Web', title: 'Prompt from link', detail: prompt.slice(0, 200) });
      appendLog('Prompt from link ✓');
    } catch (err) {
      linkPromptOutput.textContent = `Prompt generation failed: ${err.message}`;
      appendLog('Prompt from link failed');
    }
  });

  screenshotPromptForm?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const file = screenshotFile?.files?.[0];
    if (!file) {
      screenshotStatus.textContent = 'Select an image first.';
      return;
    }
    const prompt = `Generate a prompt from screenshot "${file.name}" focused on layout, typography, color, and UX intent.`;
    screenshotStatus.textContent = prompt;
    addToLibrary({ type: 'Media', title: 'Prompt from screenshot', detail: prompt.slice(0, 220) });
    appendLog(`Prompt from screenshot ✓ (${file.name})`);
  });

  financeBalanceButton?.addEventListener('click', async () => {
    financeOutput.textContent = 'Loading balance…';
    appendLog('Finance balance → load');
    try {
      const json = await callBackend('/api/finance/balance', {}, 'GET');
      financeOutput.textContent = JSON.stringify(json, null, 2);
      appendLog('Finance balance ✓');
      showToast('Finance synced');
    } catch (err) {
      financeOutput.textContent = `Finance balance failed: ${err.message}`;
      appendLog('Finance balance failed');
    }
  });

  financeAnalyzeButton?.addEventListener('click', async () => {
    financeOutput.textContent = 'Analyzing spending…';
    appendLog('Finance analyze → load');
    try {
      const json = await callBackend('/api/finance/analyze?days=7', {}, 'GET');
      financeOutput.textContent = JSON.stringify(json, null, 2);
      appendLog('Finance analyze ✓');
    } catch (err) {
      financeOutput.textContent = `Finance analyze failed: ${err.message}`;
      appendLog('Finance analyze failed');
    }
  });

  legalSummaryButton?.addEventListener('click', async () => {
    const text = (legalInput?.value || '').trim();
    if (!text) return;
    legalOutput.textContent = 'Summarizing…';
    appendLog('Legal summary → run');
    try {
      const json = await callBackend('/api/legal/summary', { text });
      legalOutput.textContent = JSON.stringify(json, null, 2);
      appendLog('Legal summary ✓');
      showToast('Legal summary ready');
    } catch (err) {
      legalOutput.textContent = `Legal summary failed: ${err.message}`;
      appendLog('Legal summary failed');
    }
  });

  legalClausesButton?.addEventListener('click', async () => {
    const text = (legalInput?.value || '').trim();
    if (!text) return;
    legalOutput.textContent = 'Extracting clauses…';
    appendLog('Legal clauses → run');
    try {
      const json = await callBackend('/api/legal/clauses', { text });
      legalOutput.textContent = JSON.stringify(json, null, 2);
      appendLog('Legal clauses ✓');
    } catch (err) {
      legalOutput.textContent = `Legal clause extraction failed: ${err.message}`;
      appendLog('Legal clauses failed');
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
        const storedAgent = localStorage.getItem('lilithAgent') || localStorage.getItem('atomAgent');
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
        const storedMode = localStorage.getItem('lilithMode') || localStorage.getItem('atomMode');
        if (storedMode) modeSelect.value = storedMode;
      }
      updateAgentModeLabel();
    } catch (err) {
      appendLog('Agents failed: ' + err.message);
    }
  }

  agentSelect?.addEventListener('change', () => {
    localStorage.setItem('lilithAgent', agentSelect.value);
    updateAgentModeLabel();
  });
  modeSelect?.addEventListener('change', () => {
    localStorage.setItem('lilithMode', modeSelect.value);
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
  let activeProjectId = null;

  projectsBtn?.addEventListener('click', async () => {
    projectsBtn.textContent = 'Loading…';
    appendLog('Projects → load');
    try {
      const json = await callBackend('/api/projects', {}, 'GET');
      const projects = Array.isArray(json) ? json : [];
      projectsList.innerHTML = '';
      projects.forEach((project) => {
        const li = document.createElement('li');
        li.textContent = `${project.name} (${project.files?.length || 0} files)`;
        projectsList.appendChild(li);
      });
      activeProjectId = projects[0]?.id || null;
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
      if (!activeProjectId) {
        const created = await callBackend('/api/projects', { name: 'Lilith Workspace', description: 'Auto-created from web shell' });
        activeProjectId = created?.id || null;
      }
      if (!activeProjectId) {
        throw new Error('No active project available');
      }
      const json = await callBackend(`/api/projects/${activeProjectId}/files`, { name: path, content, language: 'text' });
      projectsStatus.textContent = json?.name ? `Saved to ${json.name}` : 'Saved.';
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
