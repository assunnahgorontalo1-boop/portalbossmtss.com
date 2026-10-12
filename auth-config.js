/*
 * Konfigurasi frontend saja.
 * Password, secret, service-role key, dan credential database wajib berada di backend.
 * Backend harus menggunakan session cookie HttpOnly/SameSite/Secure.
 */
window.AUTH_CONFIG = Object.freeze({
  // Gunakan Project URL utama, bukan URL /rest/v1.
  // Jangan pernah menaruh sb_secret_..., password, atau service-role key di frontend.
  supabaseUrl: 'https://ccetccoywoguuhkcyvyj.supabase.co',
  supabasePublishableKey: 'sb_publishable_b-DVRQf07DMMh6VJdO9rbg_BiPOwOpe',
  googleEndpoint: '',
  loginEndpoint: '/api/auth/login',
  logoutEndpoint: '/api/auth/logout',
  sessionEndpoint: '/api/auth/session',
  forgotPasswordUrl: '/api/auth/forgot-password',
  // Domain produksi harus ditambahkan ke Supabase Auth URL Configuration.
  // Saat pengembangan lokal, kembalikan OAuth ke localhost.
  oauthRedirectTo: (window.location.protocol === 'file:'
    ? 'http://localhost:5500/'
    : ['localhost', '127.0.0.1'].includes(window.location.hostname)
      ? window.location.origin + '/'
      : 'https://www.portainventaris-bosassunnah.com/'),
  requestDefaults: { credentials: 'include', headers: { Accept: 'application/json' } },
  api: {
    dashboard: '/api/dashboard',
    inventory: '/api/inventory',
    budgets: '/api/budgets',
    procurements: '/api/procurements',
    services: '/api/services',
    maintenance: '/api/maintenance',
    mutations: '/api/mutations',
    activities: '/api/activities',
    users: '/api/users',
    settings: '/api/settings'
  },
  databaseTables: [
    'profiles', 'users', 'viewer_permissions', 'inventory', 'budgets', 'procurements', 'services',
    'mutations', 'maintenance', 'activities', 'settings'
  ],
  // Mode demo hanya berjalan di localhost; jangan gunakan untuk autentikasi produksi.
  localDevelopmentMode: true,
  temporaryAccounts: [
    { name: 'Bendahara Demo', email: 'bendahara@local.test', password: 'BendaharaDemo123!', role: 'bendahara' },
    { name: 'Viewer Demo', email: 'viewer@local.test', password: 'ViewerDemo123!', role: 'viewer' }
  ],
  sessionTimeoutMinutes: 30,
  publicLanding: true
});
