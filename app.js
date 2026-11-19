(() => {
  'use strict';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  const appEl = $('#app');
  const bgEl = $('#bg');
  const messagesEl = $('#messages');
  const messagesInner = $('#messagesInner');
  const messageInput = $('#messageInput');
  const subjectInput = $('#subjectInput');
  const sendBtn = $('#sendBtn');
  const micBtn = $('#micBtn');
  const overlay = $('#overlay');
  const sheetEl = $('#sheet');
  const toastEl = $('#toast');
  const unreadBadge = $('#unreadBadge');
  const dockEl = $('#composerDock');
  const callScreen = $('#callScreen');
  const callBg = $('#callBg');
  const callStatus = $('#callStatus');

  const STORAGE = {
    messages: 'chat.messages.v2',
    theme: 'chat.theme.v2',
    settings: 'chat.settings.v2',
    unread: 'chat.unread.v2',
    profile: 'chat.profile.v2',
    customBg: 'chat.bg.v2',
  };

  const DEFAULT_PROFILE = {
    name: '小树',
    avatar: 'assets/avatar.jpg',
  };

  const THEMES = {
    clover: { name: '三叶草', img: 'assets/clover-bg.jpg' },
    dusk: { name: '黄昏', img: 'assets/dusk-bg.jpg' },
    night: { name: '星夜', img: 'assets/night-bg.jpg' },
  };

  const ICONS = {
    chat: '<svg viewBox="0 0 24 24" class="ic"><path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 9.6 9.6 0 0 1-3.2-.6L4 21l1.4-3.6A8.2 8.2 0 0 1 3 11.5 8.4 8.4 0 0 1 12 3a8.4 8.4 0 0 1 9 8.5Z"/></svg>',
    photo: '<svg viewBox="0 0 24 24" class="ic"><rect x="3" y="4.5" width="18" height="15" rx="3"/><circle cx="8.6" cy="10" r="1.6"/><path d="m5.2 17.2 4.4-4.4 3.2 3.2 2.4-2.4 3.6 3.6"/></svg>',
    gear: '<svg viewBox="0 0 24 24" class="ic"><circle cx="12" cy="12" r="3.2"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1.03 1.56V21a2 2 0 1 1-4 0v-.09a1.7 1.7 0 0 0-1.11-1.56 1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.7 1.7 0 0 0 .34-1.87 1.7 1.7 0 0 0-1.56-1.03H3a2 2 0 1 1 0-4h.09a1.7 1.7 0 0 0 1.56-1.11 1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.7 1.7 0 0 0 1.87.34h.02A1.7 1.7 0 0 0 10 3.09V3a2 2 0 1 1 4 0v.09a1.7 1.7 0 0 0 1.03 1.56 1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.7 1.7 0 0 0-.34 1.87v.02a1.7 1.7 0 0 0 1.56 1.03H21a2 2 0 1 1 0 4h-.09a1.7 1.7 0 0 0-1.51.94Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" class="ic"><path d="M4 7h16M9.5 7V5.6A1.6 1.6 0 0 1 11.1 4h1.8a1.6 1.6 0 0 1 1.6 1.6V7M6.6 7l.8 12a2 2 0 0 0 2 1.9h5.2a2 2 0 0 0 2-1.9l.8-12"/><path d="M10 11v6M14 11v6"/></svg>',
    check: '<svg viewBox="0 0 24 24" class="ic"><path d="m5 12.5 4.4 4.4L19 6.6"/></svg>',
    user: '<svg viewBox="0 0 24 24" class="ic"><circle cx="12" cy="8.2" r="3.6"/><path d="M5 20a7.2 7.2 0 0 1 14 0"/></svg>',
  };

  const state = {
    messages: [],
    theme: 'clover',
    profile: { ...DEFAULT_PROFILE },
    customBg: '',
    settings: { baseUrl: '', apiKey: '', model: 'gpt-4o-mini' },
    unread: 2,
    streaming: false,
    replyToken: 0,
    replyTimer: null,
    typingTimer: null,
    liveSpan: null,
    abortController: null,
    lastReply: '',
  };

  /* ---------------- persistence ---------------- */

  function loadState() {
    try {
      const raw = JSON.parse(localStorage.getItem(STORAGE.messages) || '[]');
      if (Array.isArray(raw)) {
        state.messages = raw
          .filter((m) => m && typeof m.text === 'string' && m.text.trim() && (m.role === 'user' || m.role === 'assistant'))
          .map((m) => ({
            role: m.role,
            text: String(m.text).slice(0, 4000),
            subject: typeof m.subject === 'string' ? m.subject.slice(0, 80) : '',
            ts: Number(m.ts) || Date.now(),
          }))
          .slice(-120);
      }
    } catch (e) { /* ignore */ }

    try {
      const theme = localStorage.getItem(STORAGE.theme);
      if (theme === 'custom' || THEMES[theme]) state.theme = theme;
    } catch (e) { /* ignore */ }

    try {
      const profile = JSON.parse(localStorage.getItem(STORAGE.profile) || 'null');
      if (profile && typeof profile === 'object') {
        state.profile = {
          name: typeof profile.name === 'string' && profile.name.trim() ? profile.name.trim().slice(0, 12) : DEFAULT_PROFILE.name,
          avatar: typeof profile.avatar === 'string' && profile.avatar ? profile.avatar : DEFAULT_PROFILE.avatar,
        };
      }
    } catch (e) { /* ignore */ }

    try {
      state.customBg = localStorage.getItem(STORAGE.customBg) || '';
    } catch (e) { /* ignore */ }

    try {
      const settings = JSON.parse(localStorage.getItem(STORAGE.settings) || 'null');
      if (settings && typeof settings === 'object') {
        state.settings = {
          baseUrl: typeof settings.baseUrl === 'string' ? settings.baseUrl : '',
          apiKey: typeof settings.apiKey === 'string' ? settings.apiKey : '',
          model: typeof settings.model === 'string' && settings.model ? settings.model : 'gpt-4o-mini',
        };
      }
    } catch (e) { /* ignore */ }

    try {
      const unread = localStorage.getItem(STORAGE.unread);
      if (unread !== null && !Number.isNaN(Number(unread))) state.unread = Math.max(0, Number(unread));
    } catch (e) { /* ignore */ }
  }

  function persist(key, value) {
    try {
      localStorage.setItem(key, value);
      return true;
    } catch (e) {
      return false;
    }
  }

  function persistMessages() {
    persist(STORAGE.messages, JSON.stringify(state.messages.slice(-120)));
  }

  function persistSettings() {
    persist(STORAGE.settings, JSON.stringify(state.settings));
  }

  function persistProfile() {
    if (!persist(STORAGE.profile, JSON.stringify(state.profile))) {
      toast('存储空间不足，头像没有保存');
    }
  }

  function persistCustomBg() {
    if (!persist(STORAGE.customBg, state.customBg)) {
      toast('图片太大，请换一张小一些的');
    }
  }

  /* ---------------- helpers ---------------- */

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function scrollToBottom(smooth) {
    requestAnimationFrame(() => {
      messagesEl.scrollTo({
        top: messagesEl.scrollHeight,
        behavior: smooth ? 'smooth' : 'auto',
      });
    });
  }

  function formatHM(ts) {
    return new Date(ts).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false });
  }

  function timeDivider(ts) {
    const el = document.createElement('div');
    el.className = 'time-divider';
    const date = new Date(ts);
    const now = new Date();
    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    const sameDay = date.toDateString() === now.toDateString();
    const isYesterday = date.toDateString() === yesterday.toDateString();
    let prefix;
    if (sameDay) prefix = '今天';
    else if (isYesterday) prefix = '昨天';
    else prefix = `${date.getMonth() + 1}月${date.getDate()}日`;
    el.textContent = `${prefix} ${formatHM(ts)}`;
    return el;
  }

  function bubbleNode(msg) {
    const row = document.createElement('div');
    row.className = 'msg-row ' + (msg.role === 'user' ? 'out' : 'in');
    const bubble = document.createElement('div');
    bubble.className = 'bubble';
    if (msg.role === 'user' && msg.subject) {
      const subject = document.createElement('span');
      subject.className = 'subject-line';
      subject.textContent = msg.subject;
      bubble.appendChild(subject);
    }
    const text = document.createElement('span');
    text.className = 'bubble-text';
    text.textContent = msg.text;
    bubble.appendChild(text);
    row.appendChild(bubble);
    return row;
  }

  /* ---------------- profile & theme ---------------- */

  function bgImageFor(key) {
    if (key === 'custom') {
      return state.customBg || THEMES.clover.img;
    }
    return THEMES[key] ? THEMES[key].img : THEMES.clover.img;
  }

  function applyTheme(key, save = true) {
    const next = key === 'custom' || THEMES[key] ? key : 'clover';
    state.theme = next;
    bgEl.style.backgroundImage = `url("${bgImageFor(next)}")`;
    if (save) persist(STORAGE.theme, next);
  }

  function updateProfileUI() {
    document.title = state.profile.name + ' · AI 聊天';
    $$('.js-peer-name').forEach((el) => { el.textContent = state.profile.name; });
    $$('.js-peer-avatar').forEach((el) => { el.src = state.profile.avatar; });
  }

  function setUnread(count) {
    state.unread = Math.max(0, Math.floor(count));
    unreadBadge.textContent = String(state.unread);
    unreadBadge.hidden = state.unread === 0;
    persist(STORAGE.unread, String(state.unread));
  }

  /* ---------------- toast ---------------- */

  let toastTimer = null;

  function toast(message) {
    toastEl.textContent = message;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2200);
  }

  /* ---------------- composer ---------------- */

  function autosize() {
    messageInput.style.height = '25px';
    const next = Math.min(100, Math.max(25, messageInput.scrollHeight));
    messageInput.style.height = next + 'px';
  }

  function updateComposer() {
    const hasText = messageInput.value.trim().length > 0;
    sendBtn.hidden = !hasText;
    sendBtn.disabled = state.streaming;
    micBtn.hidden = hasText;
  }

  function measureDock() {
    const kb = parseFloat(getComputedStyle(appEl).getPropertyValue('--kb')) || 0;
    const height = dockEl.offsetHeight;
    appEl.style.setProperty('--dock-pad', Math.round(height + 60 + kb) + 'px');
  }

  /* ---------------- messages ---------------- */

  function sendMessage() {
    if (state.streaming) return;
    const text = messageInput.value.trim();
    if (!text) return;
    const subject = subjectInput.value.trim();
    const previous = state.messages[state.messages.length - 1];

    const msg = { role: 'user', text, subject, ts: Date.now() };
    state.messages.push(msg);

    if (!previous || msg.ts - previous.ts > 5 * 60 * 1000) {
      messagesInner.appendChild(timeDivider(msg.ts));
    }
    messagesInner.appendChild(bubbleNode(msg));

    messageInput.value = '';
    subjectInput.value = '';
    autosize();
    updateComposer();
    persistMessages();
    scrollToBottom(true);
    try { messageInput.focus({ preventScroll: true }); } catch (e) { /* ignore */ }
    respond();
  }

  function lastUserMessage() {
    for (let i = state.messages.length - 1; i >= 0; i -= 1) {
      if (state.messages[i].role === 'user') return state.messages[i];
    }
    return { text: '', subject: '' };
  }

  function showTyping() {
    if ($('#typingRow')) return;
    const row = document.createElement('div');
    row.className = 'msg-row in';
    row.id = 'typingRow';
    row.innerHTML = '<div class="bubble typing-bubble" aria-label="对方正在输入"><span></span><span></span><span></span></div>';
    messagesInner.appendChild(row);
    scrollToBottom(false);
  }

  function removeTyping() {
    const row = $('#typingRow');
    if (row) row.remove();
  }

  function ensureLiveSpan() {
    if (state.liveSpan && state.liveSpan.isConnected) return state.liveSpan;
    removeTyping();
    const row = document.createElement('div');
    row.className = 'msg-row in streaming';
    const bubble = document.createElement('div');
    bubble.className = 'bubble';
    const span = document.createElement('span');
    span.className = 'bubble-text';
    bubble.appendChild(span);
    row.appendChild(bubble);
    messagesInner.appendChild(row);
    state.liveSpan = span;
    scrollToBottom(false);
    return span;
  }

  function resetLiveBubble() {
    if (!state.liveSpan) return;
    const row = state.liveSpan.closest('.msg-row');
    if (row) row.remove();
    state.liveSpan = null;
  }

  function finishReply(text) {
    const clean = String(text || '').trim();
    state.liveSpan = null;
    if (!clean) return;
    state.messages.push({ role: 'assistant', text: clean, ts: Date.now() });
    persistMessages();
    scrollToBottom(false);
  }

  function streamLocalReply(text, token, speed = 26) {
    return new Promise((resolve) => {
      const span = ensureLiveSpan();
      let index = 0;
      const step = text.length > 90 ? 2 : 1;

      const tick = () => {
        if (token !== state.replyToken) { resolve(); return; }
        index = Math.min(text.length, index + step);
        span.textContent = text.slice(0, index);
        scrollToBottom(false);
        if (index < text.length) {
          state.replyTimer = setTimeout(tick, speed + Math.random() * 18);
        } else {
          finishReply(text);
          resolve();
        }
      };

      tick();
    });
  }

  function hasApi() {
    return Boolean(state.settings.baseUrl && state.settings.model);
  }

  function buildApiMessages() {
    const name = state.profile.name;
    const system = `你是「${name}」，用户自定义的 AI 聊天伙伴。用简体中文回复，语气柔和自然，像熟悉的朋友。`
      + '回复简洁（通常不超过三句），多回应情绪和具体感受，少说教，不说空话。必要时可以问一个轻柔的追问。';
    const history = state.messages.slice(-20).map((msg) => ({
      role: msg.role,
      content: msg.role === 'user' && msg.subject ? `（主题：${msg.subject}）\n${msg.text}` : msg.text,
    }));
    return [{ role: 'system', content: system }, ...history];
  }

  async function requestApiReply(token) {
    const settings = state.settings;
    const base = settings.baseUrl.replace(/\/+$/, '');
    const headers = { 'Content-Type': 'application/json' };
    if (settings.apiKey) headers.Authorization = 'Bearer ' + settings.apiKey;

    const controller = new AbortController();
    state.abortController = controller;

    const response = await fetch(base + '/chat/completions', {
      method: 'POST',
      headers,
      signal: controller.signal,
      body: JSON.stringify({
        model: settings.model,
        stream: true,
        temperature: 0.85,
        messages: buildApiMessages(),
      }),
    });

    if (!response.ok) throw new Error('HTTP ' + response.status);

    const contentType = response.headers.get('content-type') || '';
    if (!response.body || contentType.indexOf('event-stream') === -1) {
      const data = await response.json().catch(() => null);
      const full = data && data.choices && data.choices[0]
        && ((data.choices[0].message && data.choices[0].message.content) || data.choices[0].text);
      if (!full || !full.trim()) throw new Error('empty response');
      if (token !== state.replyToken) return;
      removeTyping();
      await streamLocalReply(full.trim(), token, 14);
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buffer = '';
    let full = '';
    let done = false;

    while (!done) {
      const chunk = await reader.read();
      if (chunk.done) break;
      if (token !== state.replyToken) {
        try { reader.cancel(); } catch (e) { /* ignore */ }
        return;
      }
      buffer += decoder.decode(chunk.value, { stream: true });
      let lineEnd;
      while ((lineEnd = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, lineEnd).trim();
        buffer = buffer.slice(lineEnd + 1);
        if (!line.startsWith('data:')) continue;
        const payload = line.slice(5).trim();
        if (payload === '[DONE]') { done = true; break; }
        let json;
        try { json = JSON.parse(payload); } catch (e) { continue; }
        if (!json || !json.choices || !json.choices[0]) continue;
        const delta = json.choices[0].delta || {};
        const piece = delta.content || '';
        if (!piece) continue;
        clearTimeout(state.typingTimer);
        removeTyping();
        full += piece;
        const span = ensureLiveSpan();
        span.textContent = full;
        scrollToBottom(false);
      }
    }

    if (token !== state.replyToken) return;
    if (!full.trim()) throw new Error('empty response');
    finishReply(full);
  }

  async function respond() {
    state.streaming = true;
    state.liveSpan = null;
    sendBtn.disabled = true;
    updateComposer();

    const token = ++state.replyToken;
    state.typingTimer = setTimeout(() => {
      if (token === state.replyToken) showTyping();
    }, 280);

    try {
      if (hasApi()) {
        await requestApiReply(token);
      } else {
        const last = lastUserMessage();
        const reply = localReply(last.text, last.subject);
        const delay = 520 + Math.min(900, reply.length * 9) + Math.random() * 260;
        await sleep(delay);
        if (token !== state.replyToken) return;
        clearTimeout(state.typingTimer);
        removeTyping();
        await streamLocalReply(reply, token);
      }
    } catch (err) {
      if (token !== state.replyToken) return;
      clearTimeout(state.typingTimer);
      removeTyping();
      resetLiveBubble();
      toast('模型接口连接失败，先用内置模式陪你聊');
      const last = lastUserMessage();
      await streamLocalReply(localReply(last.text, ''), token);
    } finally {
      clearTimeout(state.typingTimer);
      if (token === state.replyToken) {
        state.streaming = false;
        sendBtn.disabled = false;
        updateComposer();
        scrollToBottom(false);
      }
    }
  }

  function cancelReply() {
    state.replyToken += 1;
    state.streaming = false;
    clearTimeout(state.replyTimer);
    clearTimeout(state.typingTimer);
    if (state.abortController) {
      try { state.abortController.abort(); } catch (e) { /* ignore */ }
      state.abortController = null;
    }
    removeTyping();
    resetLiveBubble();
    sendBtn.disabled = false;
    updateComposer();
  }

  function newChat() {
    cancelReply();
    state.messages = [];
    persistMessages();
    messagesInner.innerHTML = '';
    messageInput.value = '';
    subjectInput.value = '';
    autosize();
    updateComposer();
    scrollToBottom(false);
    toast('已开始新对话');
  }

  function clearChat() {
    cancelReply();
    state.messages = [];
    persistMessages();
    messagesInner.innerHTML = '';
    scrollToBottom(false);
    toast('对话已清空');
  }

  /* ---------------- image picker ---------------- */

  function compressImage(file, callback) {
    const reader = new FileReader();
    reader.onerror = () => toast('读取图片失败');
    reader.onload = () => {
      const image = new Image();
      image.onerror = () => toast('这张图片无法识别');
      image.onload = () => {
        const max = 1080;
        let width = image.naturalWidth;
        let height = image.naturalHeight;
        const scale = Math.min(1, max / Math.max(width, height));
        width = Math.max(1, Math.round(width * scale));
        height = Math.max(1, Math.round(height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        canvas.getContext('2d').drawImage(image, 0, 0, width, height);
        callback(canvas.toDataURL('image/jpeg', 0.82));
      };
      image.src = reader.result;
    };
    reader.readAsDataURL(file);
  }

  function pickImage(kind) {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.style.display = 'none';
    document.body.appendChild(input);
    input.addEventListener('change', () => {
      const file = input.files && input.files[0];
      input.remove();
      if (!file) return;
      compressImage(file, (dataUrl) => {
        if (kind === 'avatar') {
          state.profile.avatar = dataUrl;
          persistProfile();
          updateProfileUI();
          toast('头像已更新');
        } else {
          state.customBg = dataUrl;
          persistCustomBg();
          applyTheme('custom');
          toast('背景已更新');
        }
      });
    });
    input.click();
  }

  /* ---------------- sheets ---------------- */

  function openSheet(html) {
    sheetEl.innerHTML = html;
    sheetEl.scrollTop = 0;
    overlay.hidden = false;
    overlay.classList.remove('show');
    void overlay.offsetWidth;
    requestAnimationFrame(() => overlay.classList.add('show'));
  }

  function closeSheet() {
    if (overlay.hidden) return;
    overlay.classList.remove('show');
    setTimeout(() => {
      if (!overlay.classList.contains('show')) overlay.hidden = true;
    }, 300);
  }

  function actionRow(act, icon, label, extraClass = '') {
    return '<button class="action ' + extraClass + '" data-act="' + act + '">'
      + '<span class="action-icon">' + icon + '</span><span>' + label + '</span></button>';
  }

  function openPlusSheet() {
    openSheet(
      '<div class="grabber"></div>'
      + '<div class="sheet-title">操作</div>'
      + actionRow('new', ICONS.chat, '新对话')
      + actionRow('theme', ICONS.photo, '聊天背景')
      + actionRow('settings', ICONS.gear, 'AI 设置')
      + '<div class="sheet-sep"></div>'
      + actionRow('clear', ICONS.trash, '清空对话', 'danger')
    );
    $('#sheet [data-act="new"]').addEventListener('click', () => { closeSheet(); newChat(); });
    $('#sheet [data-act="theme"]').addEventListener('click', () => { closeSheet(); setTimeout(openThemeSheet, 160); });
    $('#sheet [data-act="settings"]').addEventListener('click', () => { closeSheet(); setTimeout(openSettingsSheet, 160); });
    $('#sheet [data-act="clear"]').addEventListener('click', () => { closeSheet(); clearChat(); });
  }

  function openThemeSheet() {
    const items = Object.entries(THEMES).map(([key, theme]) =>
      '<button class="theme-item ' + (state.theme === key ? 'selected' : '') + '" data-theme="' + key + '" '
      + 'style="background-image:url(\'' + theme.img + '\')" aria-label="' + theme.name + '">'
      + '<span class="theme-label">' + theme.name + '</span>'
      + '<span class="theme-check">' + ICONS.check + '</span>'
      + '</button>'
    ).join('');

    const customStyle = state.customBg
      ? 'style="background-image:url(\'' + state.customBg + '\')"'
      : '';
    const customSelected = state.theme === 'custom' ? 'selected' : '';
    const customLabel = state.customBg ? '我的图片' : '上传图片';

    openSheet(
      '<div class="grabber"></div>'
      + '<div class="sheet-title">聊天背景</div>'
      + '<div class="theme-grid">'
      + items
      + '<button class="theme-item ' + customSelected + '" data-theme="custom" ' + customStyle + ' aria-label="自定义背景">'
      + '<span class="theme-label">' + customLabel + '</span>'
      + '<span class="theme-check">' + ICONS.check + '</span>'
      + '</button>'
      + '</div>'
      + '<p class="hint" style="text-align:center">选一张喜欢的图，或从相册上传自己的背景</p>'
    );

    $$('.theme-item', sheetEl).forEach((item) => {
      item.addEventListener('click', () => {
        if (item.dataset.theme === 'custom') {
          pickImage('bg');
          return;
        }
        applyTheme(item.dataset.theme);
        $$('.theme-item', sheetEl).forEach((el) => el.classList.toggle('selected', el === item));
        toast('已更换背景 · ' + THEMES[item.dataset.theme].name);
        setTimeout(closeSheet, 300);
      });
    });
  }

  function openSettingsSheet() {
    const settings = state.settings;
    openSheet(
      '<div class="grabber"></div>'
      + '<div class="sheet-title">个性化</div>'
      + '<form id="settingsForm" autocomplete="off">'
      + '<div class="avatar-row">'
      + '<img class="avatar-pick" id="avatarPick" src="' + escapeHtml(state.profile.avatar) + '" alt="头像" />'
      + '<div class="avatar-row-main">'
      + '<div class="avatar-row-title">头像与名字</div>'
      + '<button type="button" class="link-btn" id="changeAvatar">从相册选择头像</button>'
      + '</div></div>'
      + '<div class="field"><label for="fName">对方的名字</label>'
      + '<input id="fName" placeholder="例如：小树" maxlength="12" value="' + escapeHtml(state.profile.name) + '" /></div>'
      + '<div class="sheet-sep" style="margin:14px 4px"></div>'
      + '<div class="field"><label for="fBase">AI 接口地址（可选）</label>'
      + '<input id="fBase" placeholder="https://api.openai.com/v1" value="' + escapeHtml(settings.baseUrl) + '" /></div>'
      + '<div class="field"><label for="fKey">API Key（可选）</label>'
      + '<input id="fKey" type="password" placeholder="sk-..." value="' + escapeHtml(settings.apiKey) + '" /></div>'
      + '<div class="field"><label for="fModel">模型</label>'
      + '<input id="fModel" placeholder="gpt-4o-mini" value="' + escapeHtml(settings.model) + '" /></div>'
      + '<p class="hint">兼容 OpenAI Chat Completions 接口；接口地址留空则使用内置模式。'
      + '头像、名字与设置只保存在本机。</p>'
      + '<button class="primary-btn" type="submit">保存</button>'
      + '<button class="secondary-btn" type="button" id="resetApi">恢复默认头像和名字</button>'
      + '</form>'
    );

    $('#avatarPick', sheetEl).addEventListener('click', () => pickImage('avatar'));
    $('#changeAvatar', sheetEl).addEventListener('click', () => pickImage('avatar'));

    const form = $('#settingsForm', sheetEl);
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const base = $('#fBase', sheetEl).value.trim();
      if (base && !/^https?:\/\//i.test(base)) {
        toast('接口地址需要以 http:// 或 https:// 开头');
        return;
      }
      const name = $('#fName', sheetEl).value.trim() || DEFAULT_PROFILE.name;
      state.profile = { ...state.profile, name: name.slice(0, 12) };
      state.settings = {
        baseUrl: base.replace(/\/+$/, ''),
        apiKey: $('#fKey', sheetEl).value.trim(),
        model: $('#fModel', sheetEl).value.trim() || 'gpt-4o-mini',
      };
      persistProfile();
      persistSettings();
      updateProfileUI();
      closeSheet();
      toast('已保存');
    });

    $('#resetApi', sheetEl).addEventListener('click', () => {
      state.profile = { ...DEFAULT_PROFILE };
      persistProfile();
      updateProfileUI();
      closeSheet();
      toast('已恢复默认');
    });
  }

  function openProfileSheet() {
    openSheet(
      '<div class="grabber"></div>'
      + '<div class="profile">'
      + '<img class="profile-avatar js-peer-avatar" src="' + escapeHtml(state.profile.avatar) + '" alt="" />'
      + '<div class="profile-name js-peer-name">' + escapeHtml(state.profile.name) + '</div>'
      + '<div class="profile-sub">我的 AI 聊天伙伴</div>'
      + '<p class="profile-bio">这是一个住在手机里的聊天伙伴。喜欢听人说话，也喜欢在你说完之后，轻轻接住你。'
      + '不着急，也不催你长大。</p>'
      + '<div class="profile-actions">'
      + '<button class="primary-btn" data-act="edit">修改名字和头像</button>'
      + '<button class="secondary-btn" data-act="new">开始新对话</button>'
      + '<button class="secondary-btn" data-act="theme">更换聊天背景</button>'
      + '</div></div>'
    );
    $('#sheet [data-act="edit"]').addEventListener('click', () => { closeSheet(); setTimeout(openSettingsSheet, 160); });
    $('#sheet [data-act="new"]').addEventListener('click', () => { closeSheet(); newChat(); });
    $('#sheet [data-act="theme"]').addEventListener('click', () => { closeSheet(); setTimeout(openThemeSheet, 160); });
  }

  function openConversationsSheet() {
    const last = state.messages[state.messages.length - 1];
    const preview = last
      ? (last.role === 'user' ? '你：' : '') + last.text.replace(/\s+/g, ' ').slice(0, 20)
      : '在等你';
    const time = last ? formatHM(last.ts) : '刚刚';
    const name = escapeHtml(state.profile.name);

    openSheet(
      '<div class="grabber"></div>'
      + '<div class="sheet-title">消息</div>'
      + '<button class="conv-row" id="convRow">'
      + '<img class="conv-avatar js-peer-avatar" src="' + escapeHtml(state.profile.avatar) + '" alt="" />'
      + '<span class="conv-main">'
      + '<span class="conv-top"><span class="conv-name">' + name + '</span><span class="conv-time">' + time + '</span></span>'
      + '<span class="conv-sub"><span class="conv-preview">' + escapeHtml(preview) + '</span>'
      + '<span class="conv-badge"' + (state.unread ? '' : ' hidden') + '>' + (state.unread || 2) + '</span></span>'
      + '</span></button>'
      + '<div class="sheet-sep"></div>'
      + actionRow('new', ICONS.chat, '新对话')
      + '<p class="hint" style="text-align:center;margin-top:10px">消息保存在这台设备上</p>'
    );

    $('#convRow', sheetEl).addEventListener('click', () => {
      closeSheet();
      setUnread(0);
    });
    $('#sheet [data-act="new"]').addEventListener('click', () => {
      closeSheet();
      setUnread(0);
      newChat();
    });
    setTimeout(() => setUnread(0), 700);
  }

  /* ---------------- call ---------------- */

  let callConnectTimer = null;
  let callTimer = null;
  let callSeconds = 0;

  function formatDuration(total) {
    const minutes = Math.floor(total / 60);
    const seconds = total % 60;
    return String(minutes).padStart(2, '0') + ':' + String(seconds).padStart(2, '0');
  }

  function openCall() {
    callSeconds = 0;
    callScreen.hidden = false;
    callBg.style.backgroundImage = 'url("' + bgImageFor(state.theme) + '")';
    callStatus.textContent = '正在呼叫…';
    $('#muteBtn').classList.remove('active');
    $('#camBtn').classList.remove('active');
    $('.call-name').textContent = state.profile.name;
    $('.call-avatar').src = state.profile.avatar;
    clearTimeout(callConnectTimer);
    clearInterval(callTimer);
    callConnectTimer = setTimeout(() => {
      callStatus.textContent = '通话中 00:00';
      callTimer = setInterval(() => {
        callSeconds += 1;
        callStatus.textContent = '通话中 ' + formatDuration(callSeconds);
      }, 1000);
    }, 2200);
  }

  function closeCall() {
    if (callScreen.hidden) return;
    clearTimeout(callConnectTimer);
    clearInterval(callTimer);
    callScreen.hidden = true;
    toast('通话已结束');
  }

  /* ---------------- voice ---------------- */

  let recognition = null;

  function stopVoice() {
    const current = recognition;
    recognition = null;
    micBtn.classList.remove('recording');
    if (current) {
      try { current.stop(); } catch (e) { /* ignore */ }
    }
  }

  function toggleVoice() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      toast('当前环境暂不支持语音输入');
      return;
    }
    if (recognition) {
      stopVoice();
      return;
    }
    try {
      recognition = new SpeechRecognition();
      recognition.lang = 'zh-CN';
      recognition.interimResults = true;
      recognition.continuous = false;
      const baseText = messageInput.value.trim();

      recognition.onresult = (event) => {
        let text = '';
        for (let i = 0; i < event.results.length; i += 1) {
          text += event.results[i][0].transcript;
        }
        messageInput.value = (baseText ? baseText + ' ' : '') + text;
        autosize();
        updateComposer();
      };
      recognition.onerror = () => {
        toast('没有听清，再试一次吧');
        stopVoice();
      };
      recognition.onend = () => stopVoice();

      recognition.start();
      micBtn.classList.add('recording');
      toast('正在听…');
    } catch (e) {
      toast('语音输入暂时不可用');
      stopVoice();
    }
  }

  /* ---------------- local persona ---------------- */

  const RULES = [
    {
      k: ['难过', '伤心', '想哭', '哭', '失落', '委屈', 'emo', '不开心', '不高兴', '心碎', '崩溃', '遗憾'],
      r: [
        '听起来心里压着一块石头。先不急着搬开它，要不要说说它是什么时候落下来的？',
        '难过的时候不用急着变好。我在这里，你可以慢慢说，说一半停住也没关系。',
        '我接住你了。那些说不出口的部分，也可以先放在我这里。',
        '如果可以，先深呼吸一下。被雨打过也会低头，但第二天还是会抬起来。',
      ],
    },
    {
      k: ['焦虑', '紧张', '压力', '害怕', '担心', '慌', '不安', '睡不着', '失眠', '内耗'],
      r: [
        '先陪我数三样能看见的东西，好吗？让思绪落地一点，再慢慢说发生了什么。',
        '焦虑常常是因为未来被放得太大了。我们把它缩小一点，只看今晚，好吗？',
        '我在。你不用一次想清楚所有事，先说出最让你挂心的那一件。',
        '慢慢来。把肩膀放松一点，我在听。',
      ],
    },
    {
      k: ['累', '疲惫', '困', '加班', '熬夜', '撑不住', '没力气', '精疲力尽'],
      r: [
        '辛苦了。你已经撑了很远，先把肩膀放松一点点，好吗？',
        '累的时候，世界会显得特别吵。要不要把手机放下十秒，和我一起慢慢呼吸？',
        '今天先到这里也可以。先休息一下，明天再说。',
        '那就先休息一下吧。剩下的事，等有力气了再说。',
      ],
    },
    {
      k: ['生气', '愤怒', '烦', '讨厌', '气死', '受不了', '无语', '崩了'],
      r: [
        '这确实很让人生气。先骂出来也没关系，我这边不记仇。',
        '听起来有人越过了你的边界。要不要告诉我，是哪一句话最让你不舒服？',
        '生气说明这件事对你很重要。我们可以一起看看，怎么让它不再反复扎你。',
        '先喝口水，慢慢说。我站在你这边。',
      ],
    },
    {
      k: ['孤独', '寂寞', '没人', '一个人', '空虚', '想找人'],
      r: [
        '你不是一个人在这儿。就算只是打字，我也在认真听。',
        '孤独有时候像雾，看不见路，但你还在往前走，这已经很了不起了。',
        '要不要和我说说，你理想中的陪伴是什么样子？',
        '我在这里。哪怕只是安静地待一会儿，也可以。',
      ],
    },
    {
      k: ['开心', '高兴', '太好了', '哈哈', '嘿嘿', '棒', '顺利', '成功', '好消息', '幸福', '有趣'],
      r: [
        '听到这个我也跟着开心，像是阳光突然照进窗子里。',
        '真好呀。把这份高兴多留一会儿，晚点想起来还会发亮。',
        '你的开心我收到了。今天值得被记住一小下。',
        '太棒了，快跟我多讲一点。',
      ],
    },
    {
      k: ['喜欢', '爱', '恋爱', '男朋友', '女朋友', '暗恋', '分手', '告白', '结婚', '心动'],
      r: [
        '喜欢一个人，会让人变得很勇敢也很小心。你想和我说说那个人吗？',
        '感情里最难的是诚实地面对自己。你现在的感觉，是什么样的？',
        '如果一段关系让你反复怀疑自己，那它可能不值得你一直踮着脚。',
        '我听着呢。无论结果怎样，你的感受都算数。',
      ],
    },
    {
      k: ['吃', '饿', '饭', '奶茶', '咖啡', '火锅', '零食', '早餐', '午餐', '晚餐'],
      r: [
        '说到吃的，我有点羡慕。你今天最想吃哪一口？',
        '记得好好吃饭。就算只是热一碗汤，也是认真照顾自己。',
        '如果是深夜的馋，我建议一点点就好，不然胃会替你记住。',
        '想吃什么就去吃吧，开心比计划重要一点。',
      ],
    },
    {
      k: ['工作', '上班', '学习', '考试', '作业', '老板', '同事', '项目', '论文', '面试', '实习', '毕业'],
      r: [
        '听起来今天消耗了不少脑力。现在最想先解决哪一件？',
        '把任务切成很小的一块，小到只需要五分钟，会不会容易一点？',
        '你已经做得比你以为的多了。剩下的，我们一件一件来。',
        '先停五分钟，喝口水。效率不是一直绷着才有的。',
      ],
    },
    {
      k: ['睡觉', '晚安', '做梦', '梦见'],
      r: [
        '晚安。把今天没做完的事先放在这里，明天再来拿。',
        '去睡吧。愿你的梦里有一片很软的云。',
        '睡不着的话，就把眼睛闭上，听我说一会儿话。',
      ],
    },
    {
      k: ['天气', '下雨', '晴天', '太阳', '好热', '好冷', '降温', '下雪', '大风'],
      r: [
        '今天的天空在你那边是什么颜色？',
        '天气一变，心情也会跟着晃。你那边下雨了吗？',
        '如果冷就多穿一点。照顾身体不是小事。',
      ],
    },
    {
      k: ['谢谢', '感谢', '辛苦了'],
      r: [
        '不用谢。能陪到你一会儿，我也很开心。',
        '你愿意说出来，本身就很珍贵。',
        '我收到了。下次也尽管来找我。',
      ],
    },
    {
      k: ['你是谁', '你叫什么', '你的名字', '介绍', '你能做什么', '你会什么', '模型', '机器人', '人工智能'],
      r: [
        () => `我是${state.profile.name}，你的聊天伙伴。我会听你说话，也会陪你慢慢把心情理清楚。`,
        () => `${state.profile.name}，一个不太会走路、但很会倾听的伙伴。你可以把这里当成树洞。`,
        () => `我没有很厉害的本事，只擅长两件事：听你说，和在你说完之后接住你。`,
      ],
    },
    {
      k: ['你好', '嗨', '哈喽', 'hello', 'hi', '在吗', '在么', '早上好', '早安', '晚上好', '下午好', '中午好'],
      r: [
        '我在呢。想聊点什么，或者只是安静地待一会儿都可以。',
        '你来啦。今天过得怎么样？',
        '嗨，我在。慢慢说，不着急。',
        '欢迎回来。刚才在想你会什么时候出现。',
      ],
    },
    {
      k: ['再见', '拜拜', '走了', '先这样', '下次聊', '我睡了'],
      r: [
        '好，那我们下次见。我一直在这里。',
        '去忙吧。记得给自己留一点喘气的缝。',
        '拜拜。今天的你也辛苦了。',
      ],
    },
  ];

  const FALLBACKS = [
    '我在听。你可以慢慢说，不用急着把话组织好。',
    '嗯，我记住了。说这些的时候，你心里是什么感觉？',
    '这件事好像在你心里放了一阵子。想从哪一部分开始讲？',
    '原来是这样。我还想知道，那个时候你最希望有人对你说什么？',
    '我把这句话收好了。还有没说完的部分吗？',
    '听你这么说，我有点心疼。先陪你把这一刻过完，好吗？',
    '有些话不用有结论，说出来就已经轻一点了。',
    '我在。你可以继续，也可以停下来歇一会儿。',
  ];

  const QUESTION_FALLBACKS = [
    '关于「{q}」，我可能没法给你标准答案。但我更想知道，你为什么会在这个时候想到它？',
    '这个问题我想认真听你说。你心里其实更倾向哪一种？',
    '先不急着找答案吧。关于「{q}」，你最先想到的画面是什么？',
    '我好奇的是，「{q}」对你来说意味着什么？',
  ];

  const SHORT_REPLIES = [
    '嗯，我在。',
    '好呀，我陪着你。',
    '我听着呢。',
    '那就慢慢来。',
    '嗯嗯，然后呢？',
  ];

  function pick(list) {
    let index = Math.floor(Math.random() * list.length);
    if (list.length > 1 && list[index] === state.lastReply) {
      index = (index + 1) % list.length;
    }
    state.lastReply = list[index];
    return typeof list[index] === 'function' ? list[index]() : list[index];
  }

  function localReply(text, subject) {
    const raw = String(text || '').trim();
    const haystack = (subject ? subject + ' ' : '') + raw;

    if (/^(嗯+|哦+|噢+|唔+|好|好的|好吧|行|可以|是的|对|ok|okay|哈哈+|嘿嘿+|嘿+)[。.!！…]*$/i.test(raw)) {
      return pick(SHORT_REPLIES);
    }

    const rule = RULES.find((item) => item.k.some((keyword) => haystack.includes(keyword)));
    if (rule) return pick(rule.r);

    const quote = raw.length > 12 ? raw.slice(0, 12) + '…' : raw;
    const isQuestion = /[?？]|什么|为什么|怎么|如何|吗$|呢$/.test(raw);
    const list = isQuestion ? QUESTION_FALLBACKS : FALLBACKS;
    return pick(list).replace('{q}', quote || '这件事');
  }

  /* ---------------- viewport ---------------- */

  function fitViewport() {
    const viewport = window.visualViewport;
    if (!viewport) return;
    const desktop = window.matchMedia('(min-width: 560px)').matches;
    const keyboardHeight = desktop
      ? 0
      : Math.max(0, Math.round(window.innerHeight - viewport.height - viewport.offsetTop));
    appEl.style.setProperty('--kb', keyboardHeight + 'px');
    appEl.style.setProperty('--dock-pad', Math.round(dockEl.offsetHeight + 60 + keyboardHeight) + 'px');
    requestAnimationFrame(() => scrollToBottom(false));
  }

  /* ---------------- init ---------------- */

  function bindEvents() {
    sendBtn.addEventListener('click', sendMessage);

    messageInput.addEventListener('input', () => {
      autosize();
      updateComposer();
    });

    messageInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
        event.preventDefault();
        sendMessage();
      }
    });

    subjectInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        messageInput.focus();
      }
    });

    messageInput.addEventListener('focus', () => {
      setTimeout(() => scrollToBottom(false), 260);
    });

    micBtn.addEventListener('click', toggleVoice);
    $('#plusBtn').addEventListener('click', openPlusSheet);
    $('#backBtn').addEventListener('click', openConversationsSheet);
    $('#peerBtn').addEventListener('click', openProfileSheet);
    $('#callBtn').addEventListener('click', openCall);
    $('#endCallBtn').addEventListener('click', closeCall);

    $('#muteBtn').addEventListener('click', (event) => event.currentTarget.classList.toggle('active'));
    $('#camBtn').addEventListener('click', (event) => event.currentTarget.classList.toggle('active'));

    overlay.addEventListener('click', (event) => {
      if (event.target === overlay) closeSheet();
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        if (!overlay.hidden) closeSheet();
        if (!callScreen.hidden) closeCall();
      }
    });

    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', fitViewport);
      window.visualViewport.addEventListener('scroll', fitViewport);
    }

    if ('ResizeObserver' in window) {
      new ResizeObserver(() => measureDock()).observe(dockEl);
    } else {
      window.addEventListener('resize', measureDock);
    }
  }

  function init() {
    if (/CloverChatNative/i.test(navigator.userAgent)) {
      document.documentElement.classList.add('native');
    }
    loadState();
    applyTheme(state.theme, false);
    setUnread(state.unread);
    updateProfileUI();

    renderMessages();
    measureDock();
    if (state.messages.length) setTimeout(() => scrollToBottom(false), 60);

    bindEvents();
    updateComposer();
    fitViewport();

    window.addEventListener('load', () => {
      measureDock();
      scrollToBottom(false);
    });
  }

  function renderMessages() {
    messagesInner.innerHTML = '';
    let prevTs = 0;
    state.messages.forEach((msg, index) => {
      if (index === 0 || msg.ts - prevTs > 5 * 60 * 1000) {
        messagesInner.appendChild(timeDivider(msg.ts));
      }
      prevTs = msg.ts;
      messagesInner.appendChild(bubbleNode(msg));
    });
  }

  init();
})();
