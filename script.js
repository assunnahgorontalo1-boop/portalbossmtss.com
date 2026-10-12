/* Fitur tambahan: Pengaturan → Manajemen Pengguna. */
(function () {
  'use strict';

  const config = window.AUTH_CONFIG || {};
  const apiUrl = config.api && config.api.users ? config.api.users : '/api/users';
  let supabaseClient = null;
  let users = [];

  function currentProfile() {
    return window.USER_PROFILE || window.currentUser || window.AUTH_USER || {};
  }

  function roleOf(profile) {
    return String(profile.role || profile.app_role || '').toLowerCase();
  }

  function canManageUsers() {
    return ['bendahara', 'kepala_madrasah'].includes(roleOf(currentProfile()));
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, char => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[char]));
  }

  function createSupabaseClient() {
    if (supabaseClient || !window.supabase || !config.supabaseUrl || !config.supabasePublishableKey) {
      return supabaseClient;
    }
    supabaseClient = window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey);
    return supabaseClient;
  }

  async function request(path, options) {
    const response = await fetch(path, Object.assign({
      credentials: 'include',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' }
    }, options || {}));
    if (!response.ok) throw new Error((await response.text()) || 'Permintaan gagal.');
    return response.status === 204 ? null : response.json();
  }

  async function loadUsers() {
    try {
      const result = await request(apiUrl);
      return Array.isArray(result) ? result : (result.users || result.data || []);
    } catch (serverError) {
      const client = createSupabaseClient();
      if (!client) throw serverError;
      const { data, error } = await client.from('users').select('id,name,email,google_id,avatar,role,status,last_login_at,created_at,updated_at').order('name');
      if (error) throw error;
      return data || [];
    }
  }

  async function saveUser(payload) {
    try {
      return await request(apiUrl, { method: 'POST', body: JSON.stringify(payload) });
    } catch (serverError) {
      const client = createSupabaseClient();
      if (!client) throw serverError;
      const { data, error } = await client.from('users').upsert(payload, { onConflict: 'email' }).select().single();
      if (error) throw error;
      if (data && data.id) {
        await client.from('viewer_permissions').upsert({ user_id: data.id }, { onConflict: 'user_id' });
      }
      return data;
    }
  }

  function addMenuLink() {
    const menu = document.querySelector('.sidebar-menu');
    if (!menu || document.querySelector('[data-target="userManagementSection"]')) return;
    if (!canManageUsers()) return;
    const group = document.createElement('div');
    group.className = 'sidebar-group user-management-menu';
    group.innerHTML = '<button type="button" class="sidebar-link sidebar-sub-link" data-target="userManagementSection"><span class="menu-icon">♙</span>Manajemen Pengguna</button>';
    const settingsGroup = [...menu.querySelectorAll('.sidebar-group')].find(item => /pengaturan/i.test(item.textContent));
    (settingsGroup || menu).appendChild(group);
  }

  function createPanel() {
    if (document.getElementById('userManagementSection')) return;
    const section = document.createElement('section');
    section.id = 'userManagementSection';
    section.className = 'settings-section app-page';
    section.dataset.page = 'userManagementSection';
    section.innerHTML = `
      <div class="settings-card user-management-card">
        <div class="user-management-heading">
          <div><h2>Manajemen Pengguna</h2><p>Daftarkan akun Google sebelum pengguna memperoleh akses ke aplikasi.</p></div>
          <button class="btn btn-primary" id="addUserButton" type="button">＋ Tambah Pengguna</button>
        </div>
        <div id="userManagementMessage" class="user-management-message" role="status"></div>
        <div class="table-wrap user-management-table"><div class="scroll"><table>
          <thead><tr><th>Nama</th><th>Email Google</th><th>Role</th><th>Status</th><th>Terakhir Login</th></tr></thead>
          <tbody id="userManagementRows"><tr><td colspan="5" class="empty-state">Memuat pengguna…</td></tr></tbody>
        </table></div></div>
      </div>`;
    document.body.appendChild(section);

    const overlay = document.createElement('div');
    overlay.id = 'addUserOverlay';
    overlay.className = 'overlay';
    overlay.innerHTML = `<div class="modal" role="dialog" aria-modal="true" aria-labelledby="addUserTitle">
      <h2 id="addUserTitle">Tambah Pengguna</h2>
      <p class="modal-intro">Pengguna harus login menggunakan akun Google dengan email yang sama.</p>
      <form id="addUserForm"><div class="form-grid">
        <div class="full"><label for="newUserName">Nama</label><input id="newUserName" required maxlength="120"></div>
        <div class="full"><label for="newUserEmail">Email Google</label><input id="newUserEmail" type="email" required maxlength="254"></div>
        <div><label for="newUserRole">Role</label><select id="newUserRole"><option value="viewer">Viewer</option><option value="bendahara">Bendahara</option><option value="kepala_madrasah">Kepala Madrasah</option></select></div>
        <div><label for="newUserStatus">Status</label><select id="newUserStatus"><option value="active">Aktif</option><option value="inactive">Nonaktif</option></select></div>
      </div><div class="modal-actions"><button type="button" class="btn btn-ghost" id="cancelAddUser">Batal</button><button type="submit" class="btn btn-primary">Simpan</button></div></form>
    </div>`;
    document.body.appendChild(overlay);

    document.getElementById('addUserButton').onclick = () => overlay.classList.add('show');
    document.getElementById('cancelAddUser').onclick = () => overlay.classList.remove('show');
    document.getElementById('addUserForm').onsubmit = async event => {
      event.preventDefault();
      const message = document.getElementById('userManagementMessage');
      const payload = {
        name: document.getElementById('newUserName').value.trim(),
        email: document.getElementById('newUserEmail').value.trim().toLowerCase(),
        role: document.getElementById('newUserRole').value,
        status: document.getElementById('newUserStatus').value
      };
      try {
        await saveUser(payload);
        overlay.classList.remove('show');
        event.target.reset();
        message.textContent = 'Pengguna berhasil didaftarkan.';
        await renderUsers();
      } catch (error) {
        message.textContent = error.message || 'Pengguna gagal disimpan.';
      }
    };
  }

  async function renderUsers() {
    const rows = document.getElementById('userManagementRows');
    if (!rows || !canManageUsers()) return;
    try {
      users = await loadUsers();
      rows.innerHTML = users.length ? users.map(user => `<tr>
        <td>${escapeHtml(user.name)}</td><td>${escapeHtml(user.email)}</td>
        <td>${escapeHtml(user.role)}</td><td>${user.status === 'active' ? 'Aktif' : 'Nonaktif'}</td>
        <td>${user.last_login_at ? new Date(user.last_login_at).toLocaleString('id-ID') : 'Belum login'}</td>
      </tr>`).join('') : '<tr><td colspan="5" class="empty-state">Belum ada pengguna terdaftar.</td></tr>';
    } catch (error) {
      rows.innerHTML = `<tr><td colspan="5" class="empty-state">${escapeHtml(error.message || 'Data pengguna tidak dapat dimuat.')}</td></tr>`;
    }
  }

  function bindNavigation() {
    document.addEventListener('click', event => {
      const link = event.target.closest('[data-target="userManagementSection"]');
      if (!link || !canManageUsers()) return;
      event.preventDefault();
      document.querySelectorAll('.app-page').forEach(page => { page.classList.remove('active'); page.style.display = 'none'; });
      const section = document.getElementById('userManagementSection');
      section.classList.add('active'); section.style.display = 'block';
      document.body.dataset.page = 'userManagementSection';
      renderUsers();
    });
  }

  function init() {
    if (!canManageUsers()) return;
    createPanel();
    addMenuLink();
    bindNavigation();
  }

  document.addEventListener('DOMContentLoaded', () => {
    let attempts = 0;
    const waitForProfile = setInterval(() => {
      attempts += 1;
      init();
      if (canManageUsers() || attempts >= 20) clearInterval(waitForProfile);
    }, 500);
  });
  window.initUserManagement = init;
})();

/* Email/password authentication is handled by Supabase Auth, not by the app users table. */
(function () {
  'use strict';

  const config = window.AUTH_CONFIG || {};
  let client = null;

  function getClient() {
    if (!client && window.supabase && config.supabaseUrl && config.supabasePublishableKey) {
      client = window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey);
    }
    return client;
  }

  function showLoginError(message) {
    const errorElement = document.getElementById('loginError');
    if (errorElement) errorElement.textContent = message;
  }

  function completeLocalLogin(account) {
    const profile = {
      id: `local-${account.role}`,
      name: account.name,
      email: account.email,
      role: account.role,
      status: 'active'
    };
    window.AUTH_USER = { id: profile.id, email: profile.email, isLocal: true };
    window.USER_PROFILE = profile;
    window.currentUser = profile;
    document.body.classList.remove('login-locked');
    document.body.classList.toggle('viewer-mode', account.role === 'viewer');
    document.body.classList.remove('public-landing-open');
    const loginScreen = document.getElementById('loginScreen');
    if (loginScreen) loginScreen.style.display = 'none';
    document.dispatchEvent(new CustomEvent('auth:login', { detail: { user: window.AUTH_USER, profile, local: true } }));
  }

  function localLoginEnabled() {
    const host = window.location.hostname || '';
    const isFileOrigin = window.location.protocol === 'file:' || host === '';
    const localHost = ['localhost', '127.0.0.1', '[::1]', ''].includes(host);
    const embeddedPreview = window.self !== window.top;
    const demoQuery = new URLSearchParams(window.location.search).get('demo') === '1';
    return config.localDevelopmentMode === true && (localHost || isFileOrigin || embeddedPreview || demoQuery);
  }

  async function findAuthorizedProfile(supabaseClient, authUser) {
    const { data: appUser, error: userError } = await supabaseClient
      .from('users')
      .select('auth_user_id,name,email,role,status')
      .eq('email', String(authUser.email || '').toLowerCase())
      .maybeSingle();

    if (userError && userError.code !== 'PGRST116') throw userError;
    if (appUser) {
      if (appUser.auth_user_id !== authUser.id || appUser.status !== 'active') return null;
      return { id: authUser.id, name: appUser.name, email: appUser.email, role: appUser.role, status: appUser.status };
    }

    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('id,nama,email,role,status')
      .eq('id', authUser.id)
      .maybeSingle();

    if (profileError) throw profileError;
    if (!profile || profile.status !== 'aktif') return null;
    return { id: profile.id, name: profile.nama, email: profile.email || authUser.email, role: profile.role, status: 'active' };
  }

  function bindEmailLogin() {
    const loginButton = document.getElementById('loginSubmit');
    const form = loginButton && loginButton.closest('form');
    if (!form || form.dataset.supabaseEmailLoginBound) return;

    const emailInput = form.querySelector('input[type="email"]');
    const passwordInput = form.querySelector('input[type="password"]');
    if (!emailInput || !passwordInput) return;
    form.dataset.supabaseEmailLoginBound = 'true';

    form.addEventListener('submit', async event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      const email = emailInput.value.trim().toLowerCase();
      if (localLoginEnabled()) {
        const localAccount = (config.temporaryAccounts || []).find(account =>
          String(account.email).toLowerCase() === email && account.password === passwordInput.value
        );
        if (localAccount && ['bendahara', 'viewer'].includes(localAccount.role)) {
          showLoginError('');
          completeLocalLogin(localAccount);
          return;
        }
      }

      const supabaseClient = getClient();
      if (!supabaseClient) {
        showLoginError(localLoginEnabled()
          ? 'Akun lokal tidak cocok. Gunakan akun demo yang dikonfigurasi atau layanan Supabase.'
          : 'Login lokal hanya tersedia di localhost. Periksa konfigurasi Supabase untuk login di situs ini.');
        return;
      }

      const button = document.getElementById('loginSubmit');
      const originalText = button ? button.textContent : '';
      if (button) { button.disabled = true; button.textContent = 'Memeriksa…'; }
      showLoginError('');

      try {
        const { data, error } = await supabaseClient.auth.signInWithPassword({
          email: emailInput.value.trim().toLowerCase(),
          password: passwordInput.value
        });
        if (error) throw error;

        const profile = await findAuthorizedProfile(supabaseClient, data.user);
        if (!profile) {
          await supabaseClient.auth.signOut();
          throw new Error('Akun belum terdaftar atau berstatus nonaktif. Hubungi administrator.');
        }

        // Backend exchanges the verified Supabase login for the app's HttpOnly session cookie.
        const backendResponse = await fetch(config.loginEndpoint || '/api/auth/login', {
          method: 'POST',
          credentials: 'include',
          headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: emailInput.value.trim().toLowerCase(),
            password: passwordInput.value,
            access_token: data.session && data.session.access_token
          })
        });
        if (!backendResponse.ok) {
          await supabaseClient.auth.signOut();
          throw new Error('Login email terverifikasi, tetapi sesi aplikasi gagal dibuat. Periksa endpoint backend /api/auth/login.');
        }

        window.AUTH_USER = data.user;
        window.USER_PROFILE = profile;
        window.currentUser = profile;
        document.body.classList.remove('login-locked');
        document.body.classList.remove('public-landing-open');
        const loginScreen = document.getElementById('loginScreen');
        if (loginScreen) loginScreen.style.display = 'none';
        document.dispatchEvent(new CustomEvent('auth:login', { detail: { user: data.user, profile } }));
      } catch (error) {
        showLoginError(error.message || 'Login gagal. Periksa email dan password Anda.');
      } finally {
        if (button) { button.disabled = false; button.textContent = originalText; }
      }
    }, true);
  }

  document.addEventListener('DOMContentLoaded', bindEmailLogin);
  bindEmailLogin();
})();

function showTime() {
  const element = document.getElementById('currentTime');
  if (element) element.textContent = new Date().toUTCString();
}
showTime();
setInterval(showTime, 1000);
