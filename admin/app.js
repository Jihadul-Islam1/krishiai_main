/* ============================================================
   Krishi AI Admin Panel — Application Logic
   ============================================================
   
   Connects to the same Firebase Firestore project (krishi-ai-bd)
   that the Flutter app uses. Writes to `market_prices_live`
   collection which the app's MarketRepository reads via
   `_fetchFirestoreLive()` and `watch()`.
   ============================================================ */

// ======================== Firebase Init ========================
const firebaseConfig = {
  apiKey: 'AIzaSyDHBLTxz2tJFI0W5RQZZzeEkGUe8jNeXm0',
  authDomain: 'krishi-ai-bd.firebaseapp.com',
  projectId: 'krishi-ai-bd',
  storageBucket: 'krishi-ai-bd.firebasestorage.app',
  messagingSenderId: '1090788492957',
  appId: '1:1090788492957:web:f6c53267fcf68bfe82f674',
  measurementId: 'G-1RMX9RXWV3',
};

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const COLLECTION = 'market_prices_live';

// ======================== State ========================
let allProducts = [];
let currentFilter = null;
let pendingConfirmAction = null;
let unsubscribe = null; // Firestore real-time listener

// ======================== Admin Auth ========================
// Simple client-side password gate. For production, use Firebase Auth.
const ADMIN_HASH = '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918'; // SHA-256 of "admin"

async function sha256(message) {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

async function authenticate() {
  const pass = document.getElementById('admin-pass').value.trim();
  if (!pass) {
    showAuthError('পাসওয়ার্ড দিন');
    return;
  }
  const hash = await sha256(pass);
  if (hash === ADMIN_HASH) {
    sessionStorage.setItem('admin_auth', '1');
    showApp();
  } else {
    showAuthError('ভুল পাসওয়ার্ড! আবার চেষ্টা করুন।');
  }
}

function showAuthError(msg) {
  const el = document.getElementById('auth-error');
  el.textContent = msg;
  el.hidden = false;
}

function togglePassVisibility() {
  const inp = document.getElementById('admin-pass');
  const eye = document.getElementById('pass-eye');
  if (inp.type === 'password') {
    inp.type = 'text';
    eye.textContent = 'visibility';
  } else {
    inp.type = 'password';
    eye.textContent = 'visibility_off';
  }
}

function logout() {
  sessionStorage.removeItem('admin_auth');
  if (unsubscribe) unsubscribe();
  document.getElementById('app').hidden = true;
  document.getElementById('auth-gate').hidden = false;
  document.getElementById('admin-pass').value = '';
}

function showApp() {
  document.getElementById('auth-gate').hidden = true;
  document.getElementById('app').hidden = false;
  startRealtimeSync();
}

// Enter key on password field
document.getElementById('admin-pass').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') authenticate();
});

// Auto-login if session still valid
if (sessionStorage.getItem('admin_auth') === '1') {
  showApp();
}

// ======================== Firestore Real-time Sync ========================
function startRealtimeSync() {
  setSyncStatus('syncing', 'সিঙ্ক হচ্ছে...');
  
  unsubscribe = db.collection(COLLECTION)
    .orderBy('updatedAt', 'desc')
    .onSnapshot(
      (snapshot) => {
        allProducts = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          allProducts.push({ ...data, _docId: doc.id });
        });
        updateDashboard();
        renderProducts();
        renderRecentList();
        renderCategoryChips();
        setSyncStatus('synced', 'সিঙ্ক');
      },
      (error) => {
        console.error('Firestore listener error:', error);
        setSyncStatus('error', 'সিঙ্ক ব্যর্থ');
        showToast('Firestore সংযোগ ব্যর্থ: ' + error.message, 'error');
      }
    );
}

function setSyncStatus(status, label) {
  const badge = document.getElementById('sync-status');
  badge.className = 'sync-badge' + (status === 'syncing' ? ' syncing' : '');
  badge.innerHTML = `
    <span class="material-icons-round">${
      status === 'synced' ? 'cloud_done' :
      status === 'syncing' ? 'sync' : 'cloud_off'
    }</span>
    ${label}
  `;
}

// ======================== Dashboard ========================
function updateDashboard() {
  document.getElementById('stat-total').textContent = allProducts.length;
  
  const cats = new Set(allProducts.map(p => p.category || 'অন্যান্য'));
  document.getElementById('stat-categories').textContent = cats.size;
  
  const today = new Date().toISOString().split('T')[0];
  const todayCount = allProducts.filter(p => {
    if (!p.updatedAt) return false;
    const d = p.updatedAt.toDate ? p.updatedAt.toDate() : new Date(p.updatedAt);
    return d.toISOString().split('T')[0] === today;
  }).length;
  document.getElementById('stat-updated').textContent = todayCount;
  
  if (allProducts.length > 0) {
    const latest = allProducts[0];
    const d = latest.updatedAt?.toDate ? latest.updatedAt.toDate() : new Date(latest.updatedAt || Date.now());
    document.getElementById('stat-last-update').textContent = formatDateBn(d);
  } else {
    document.getElementById('stat-last-update').textContent = '—';
  }
}

function renderRecentList() {
  const container = document.getElementById('recent-list');
  const recent = allProducts.slice(0, 10);
  
  if (recent.length === 0) {
    container.innerHTML = '<p class="empty-msg">কোনো পণ্য নেই। নতুন পণ্য যোগ করুন!</p>';
    return;
  }
  
  container.innerHTML = `
    <table class="data-table">
      <thead>
        <tr>
          <th>পণ্য</th>
          <th>দাম</th>
          <th>ক্যাটাগরি</th>
          <th>প্রবণতা</th>
          <th>আপডেট</th>
          <th>একশন</th>
        </tr>
      </thead>
      <tbody>
        ${recent.map(p => productRow(p)).join('')}
      </tbody>
    </table>
  `;
}

// ======================== Products ========================
function renderProducts() {
  const container = document.getElementById('products-table');
  let filtered = [...allProducts];
  
  // Search filter
  const query = (document.getElementById('search-input')?.value || '').trim().toLowerCase();
  if (query) {
    filtered = filtered.filter(p =>
      (p.cropName || '').toLowerCase().includes(query) ||
      (p.id || '').toLowerCase().includes(query) ||
      (p.category || '').toLowerCase().includes(query)
    );
  }
  
  // Category filter
  if (currentFilter) {
    filtered = filtered.filter(p => p.category === currentFilter);
  }
  
  if (filtered.length === 0) {
    container.innerHTML = `<p class="empty-msg">${query || currentFilter ? 'কোনো ফলাফল পাওয়া যায়নি' : 'কোনো পণ্য নেই। নতুন পণ্য যোগ করুন!'}</p>`;
    return;
  }
  
  container.innerHTML = `
    <table class="data-table">
      <thead>
        <tr>
          <th>পণ্য</th>
          <th>বর্তমান দাম</th>
          <th>আগের দাম</th>
          <th>মিন / ম্যাক্স</th>
          <th>ক্যাটাগরি</th>
          <th>প্রবণতা</th>
          <th>আপডেট</th>
          <th>একশন</th>
        </tr>
      </thead>
      <tbody>
        ${filtered.map(p => productRowFull(p)).join('')}
      </tbody>
    </table>
  `;
}

function productRow(p) {
  const trend = getTrend(p);
  const date = p.updatedAt?.toDate ? p.updatedAt.toDate() : new Date(p.updatedAt || Date.now());
  
  return `
    <tr>
      <td>
        <div class="crop-name">${esc(p.cropName || '')}</div>
        <div class="crop-id">${esc(p.id || p._docId)}</div>
      </td>
      <td class="price-cell">৳${num(p.currentPrice)} <span class="price-unit">/${esc(p.unit || 'কেজি')}</span></td>
      <td><span class="category-pill">${esc(p.category || 'অন্যান্য')}</span></td>
      <td>${trendBadge(trend)}</td>
      <td class="date-cell">${formatDateBn(date)}</td>
      <td class="actions-cell">
        <button class="btn-icon" onclick="editProduct('${esc(p._docId)}')" title="সম্পাদনা">
          <span class="material-icons-round">edit</span>
        </button>
        <button class="btn-icon danger" onclick="confirmDelete('${esc(p._docId)}', '${esc(p.cropName)}')" title="মুছুন">
          <span class="material-icons-round">delete</span>
        </button>
      </td>
    </tr>
  `;
}

function productRowFull(p) {
  const trend = getTrend(p);
  const date = p.updatedAt?.toDate ? p.updatedAt.toDate() : new Date(p.updatedAt || Date.now());
  
  return `
    <tr>
      <td>
        <div class="crop-name">${esc(p.cropName || '')}</div>
        <div class="crop-id">${esc(p.id || p._docId)}</div>
      </td>
      <td class="price-cell">৳${num(p.currentPrice)}</td>
      <td>৳${num(p.previousPrice || p.currentPrice)}</td>
      <td>৳${num(p.minPrice || 0)} – ৳${num(p.maxPrice || 0)}</td>
      <td><span class="category-pill">${esc(p.category || 'অন্যান্য')}</span></td>
      <td>${trendBadge(trend)}</td>
      <td class="date-cell">${formatDateBn(date)}</td>
      <td class="actions-cell">
        <button class="btn-icon" onclick="editProduct('${esc(p._docId)}')" title="সম্পাদনা">
          <span class="material-icons-round">edit</span>
        </button>
        <button class="btn-icon danger" onclick="confirmDelete('${esc(p._docId)}', '${esc(p.cropName)}')" title="মুছুন">
          <span class="material-icons-round">delete</span>
        </button>
      </td>
    </tr>
  `;
}

function renderCategoryChips() {
  const container = document.getElementById('category-chips');
  if (!container) return;
  
  const cats = [...new Set(allProducts.map(p => p.category || 'অন্যান্য'))].sort();
  
  container.innerHTML = `
    <button class="filter-chip ${!currentFilter ? 'active' : ''}" onclick="setFilter(null)">সব</button>
    ${cats.map(c => `
      <button class="filter-chip ${currentFilter === c ? 'active' : ''}" onclick="setFilter('${esc(c)}')">${esc(c)}</button>
    `).join('')}
  `;
}

function setFilter(cat) {
  currentFilter = cat;
  renderProducts();
  renderCategoryChips();
}

function filterProducts() {
  renderProducts();
}

// ======================== Save Product ========================
async function saveProduct(e) {
  e.preventDefault();
  
  const btn = document.getElementById('save-btn');
  const btnText = document.getElementById('save-btn-text');
  btn.disabled = true;
  btnText.innerHTML = '<span class="spinner"></span> সেভ হচ্ছে...';
  
  const editId = document.getElementById('edit-id').value;
  const docId = document.getElementById('f-id').value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
  const cropName = document.getElementById('f-cropName').value.trim();
  const category = document.getElementById('f-category').value;
  const unit = document.getElementById('f-unit').value;
  const currentPrice = parseFloat(document.getElementById('f-currentPrice').value) || 0;
  const previousPrice = parseFloat(document.getElementById('f-previousPrice').value) || currentPrice;
  const minPrice = parseFloat(document.getElementById('f-minPrice').value) || Math.round(currentPrice * 0.93);
  const maxPrice = parseFloat(document.getElementById('f-maxPrice').value) || Math.round(currentPrice * 1.07);
  const market = document.getElementById('f-market').value.trim();
  
  if (!docId || !cropName || !category || currentPrice <= 0) {
    showToast('সকল প্রয়োজনীয় ফিল্ড পূরণ করুন', 'error');
    btn.disabled = false;
    btnText.textContent = 'সেভ করুন';
    return;
  }
  
  const data = {
    id: docId,
    cropName,
    category,
    unit,
    currentPrice,
    previousPrice,
    minPrice,
    maxPrice,
    source: 'Admin',
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  };
  
  if (market) data.market = market;
  
  try {
    // Use the docId as the Firestore document ID so the Flutter app
    // can merge by ID (see MarketRepository._parseFirestoreLive).
    const targetId = editId || docId;
    await db.collection(COLLECTION).doc(targetId).set(data, { merge: true });
    
    showToast(editId ? `"${cropName}" আপডেট হয়েছে ✓` : `"${cropName}" যোগ হয়েছে ✓`, 'success');
    resetForm();
    switchSection('products');
  } catch (err) {
    console.error('Save failed:', err);
    showToast('সেভ ব্যর্থ: ' + err.message, 'error');
  } finally {
    btn.disabled = false;
    btnText.textContent = 'সেভ করুন';
  }
}

// ======================== Edit ========================
function editProduct(docId) {
  const product = allProducts.find(p => p._docId === docId);
  if (!product) return;
  
  document.getElementById('edit-id').value = docId;
  document.getElementById('f-id').value = product.id || docId;
  document.getElementById('f-id').readOnly = true;
  document.getElementById('f-cropName').value = product.cropName || '';
  document.getElementById('f-category').value = product.category || '';
  document.getElementById('f-unit').value = product.unit || 'কেজি';
  document.getElementById('f-currentPrice').value = product.currentPrice || '';
  document.getElementById('f-previousPrice').value = product.previousPrice || '';
  document.getElementById('f-minPrice').value = product.minPrice || '';
  document.getElementById('f-maxPrice').value = product.maxPrice || '';
  document.getElementById('f-market').value = product.market || '';
  
  document.getElementById('form-title').innerHTML = `
    <span class="material-icons-round">edit</span>
    "${product.cropName}" সম্পাদনা
  `;
  document.getElementById('save-btn-text').textContent = 'আপডেট করুন';
  
  switchSection('add');
}

// ======================== Delete ========================
function confirmDelete(docId, name) {
  document.getElementById('confirm-title').textContent = 'পণ্য মুছুন?';
  document.getElementById('confirm-msg').textContent = `"${name}" পণ্যটি মুছে ফেলতে চান? এই পরিবর্তন অ্যাপেও প্রতিফলিত হবে।`;
  document.getElementById('confirm-overlay').hidden = false;
  pendingConfirmAction = () => deleteProduct(docId);
}

async function confirmAction() {
  if (pendingConfirmAction) {
    await pendingConfirmAction();
    pendingConfirmAction = null;
  }
  closeConfirm();
}

function closeConfirm() {
  document.getElementById('confirm-overlay').hidden = true;
  pendingConfirmAction = null;
}

async function deleteProduct(docId) {
  try {
    await db.collection(COLLECTION).doc(docId).delete();
    showToast('পণ্য মুছে ফেলা হয়েছে ✓', 'success');
  } catch (err) {
    showToast('মুছতে ব্যর্থ: ' + err.message, 'error');
  }
}

// ======================== Form Reset ========================
function resetForm() {
  document.getElementById('product-form').reset();
  document.getElementById('edit-id').value = '';
  document.getElementById('f-id').readOnly = false;
  document.getElementById('form-title').innerHTML = `
    <span class="material-icons-round">add_circle</span>
    নতুন পণ্য যোগ করুন
  `;
  document.getElementById('save-btn-text').textContent = 'সেভ করুন';
}

// ======================== Auto-generate ID ========================
document.getElementById('f-cropName').addEventListener('input', function() {
  const editId = document.getElementById('edit-id').value;
  if (editId) return; // Don't auto-generate when editing
  
  const name = this.value.trim();
  // Simple transliteration for common crops
  const map = {
    'আলু': 'potato', 'পেঁয়াজ': 'onion', 'রসুন': 'garlic',
    'টমেটো': 'tomato', 'বেগুন': 'brinjal', 'ঢেঁড়স': 'ladies_finger',
    'আদা': 'ginger', 'মরিচ': 'chili', 'চাল': 'rice',
    'গম': 'wheat', 'ডাল': 'lentil', 'মাছ': 'fish',
  };
  
  let id = '';
  for (const [bn, en] of Object.entries(map)) {
    if (name.includes(bn)) {
      id = en + '_' + Date.now().toString(36).slice(-4);
      break;
    }
  }
  if (!id && name) {
    id = 'product_' + Date.now().toString(36).slice(-6);
  }
  
  document.getElementById('f-id').value = id;
});

// ======================== Navigation ========================
function switchSection(section) {
  // Hide all sections
  document.querySelectorAll('.section').forEach(s => s.hidden = true);
  document.getElementById(`section-${section}`).hidden = false;
  
  // Update nav
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.querySelector(`.nav-item[data-section="${section}"]`)?.classList.add('active');
  
  // Update title
  const titles = {
    dashboard: ['ড্যাশবোর্ড', 'সকল পণ্যের দাম পরিচালনা'],
    products:  ['পণ্য তালিকা', 'সকল পণ্য দেখুন ও সম্পাদনা করুন'],
    add:       ['পণ্য যোগ/সম্পাদনা', 'নতুন পণ্যের দাম যোগ করুন'],
  };
  const [title, sub] = titles[section] || ['', ''];
  document.getElementById('page-title').textContent = title;
  document.getElementById('page-subtitle').textContent = sub;
  
  // Close sidebar on mobile
  document.querySelector('.sidebar')?.classList.remove('open');
}

function toggleSidebar() {
  document.querySelector('.sidebar').classList.toggle('open');
}

// Close sidebar when clicking outside on mobile
document.addEventListener('click', (e) => {
  const sidebar = document.querySelector('.sidebar');
  const toggle = document.querySelector('.menu-toggle');
  if (sidebar?.classList.contains('open') && 
      !sidebar.contains(e.target) && 
      !toggle.contains(e.target)) {
    sidebar.classList.remove('open');
  }
});

// ======================== Toast ========================
function showToast(msg, type = 'success') {
  const toast = document.getElementById('toast');
  const icon = document.getElementById('toast-icon');
  const text = document.getElementById('toast-msg');
  
  toast.className = `toast ${type}`;
  icon.textContent = type === 'success' ? 'check_circle' : type === 'error' ? 'error' : 'info';
  text.textContent = msg;
  
  toast.hidden = false;
  // Force reflow
  void toast.offsetWidth;
  toast.classList.add('show');
  
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.hidden = true, 400);
  }, 3000);
}

// ======================== Helpers ========================
function getTrend(p) {
  const curr = p.currentPrice || 0;
  const prev = p.previousPrice || curr;
  const delta = curr - prev;
  if (delta > 0.5) return 'up';
  if (delta < -0.5) return 'down';
  return 'stable';
}

function trendBadge(trend) {
  const labels = {
    up:     ['trending_up', 'বাড়তি', 'trend-up'],
    down:   ['trending_down', 'কমতি', 'trend-down'],
    stable: ['trending_flat', 'স্থিতিশীল', 'trend-stable'],
  };
  const [icon, label, cls] = labels[trend];
  return `<span class="trend-badge ${cls}"><span class="material-icons-round" style="font-size:14px">${icon}</span> ${label}</span>`;
}

function formatDateBn(date) {
  if (!date) return '—';
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) return '—';
  
  const now = new Date();
  const diff = now - d;
  const mins = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  
  if (mins < 1) return 'এইমাত্র';
  if (mins < 60) return `${mins} মিনিট আগে`;
  if (hours < 24) return `${hours} ঘণ্টা আগে`;
  
  const day = d.getDate();
  const months = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন', 'জুলা', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
  return `${day} ${months[d.getMonth()]}`;
}

function esc(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function num(n) {
  if (n == null || isNaN(n)) return '0';
  return parseFloat(n).toLocaleString('bn-BD', { maximumFractionDigits: 1 });
}
