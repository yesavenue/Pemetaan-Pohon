const config = JSON.parse(document.getElementById('public-config').textContent);
const hero = document.getElementById('hero-content');
const header = document.getElementById('header');
let ticking = false;
let exited = false;
function updateScroll() {
  ticking = false;
  const focused = hero.contains(document.activeElement) || header.contains(document.activeElement);
  const progress = focused ? 0 : Math.max(0, Math.min(1, (window.scrollY - 24) / 160));
  document.documentElement.style.setProperty('--progress', progress);
  hero.inert = progress >= 1;
  header.inert = progress >= 1;
  if (progress > 0 && !exited) {
    exited = true;
    hero.classList.add('glitch-out');
  }
}
function scheduleScroll() {
  if (!ticking) { ticking = true; requestAnimationFrame(updateScroll); }
}
window.addEventListener('scroll', scheduleScroll, { passive: true });
window.addEventListener('pageshow', scheduleScroll);
document.addEventListener('focusin', scheduleScroll);
document.addEventListener('focusout', scheduleScroll);
// A fragment is not sent to the host in HTTP requests. Never place access
// codes in a query string, analytics event, localStorage, or public data fetch.
document.getElementById('tracking').addEventListener('submit', event => {
  event.preventDefault();
  const input = document.getElementById('tracking-code');
  const code = input.value.trim().toLowerCase();
  const valid = /^[a-z2-7]{16}$/.test(code) || /^[a-f0-9]{64}$/.test(code);
  const error = document.getElementById('tracking-error');
  if (code && !valid) {
    error.textContent = 'Periksa kode akses 16 karakter. Kode lama 64 karakter tetap berlaku.';
    input.setAttribute('aria-invalid', 'true');
    input.focus();
    return;
  }
  input.removeAttribute('aria-invalid');
  error.textContent = '';
  location.assign('/app/#/lacak' + (code ? '?code=' + encodeURIComponent(code) : ''));
});
let dataModule;
async function module() {
  if (!dataModule) dataModule = import(config.treeModule).catch(error => {
    dataModule = undefined;
    throw error;
  });
  return dataModule;
}
async function loadSummary(force = false) {
  try { await (await module()).loadSummary(config, force); }
  catch {
    document.getElementById('data-status').textContent = 'Data belum berhasil dimuat. Tekan Perbarui data untuk mencoba lagi.';
  }
}
document.getElementById('refresh-data').addEventListener('click', () => loadSummary(true));
for (const button of document.querySelectorAll('[data-condition]')) {
  button.addEventListener('click', async () => {
    await loadSummary();
    if (dataModule) (await dataModule).selectCondition(button.dataset.condition);
  });
}
document.getElementById('activate-map').addEventListener('click', async () => {
  const button = document.getElementById('activate-map');
  button.disabled = true;
  document.getElementById('map-status').textContent = 'Memuat peta…';
  try {
    await (await module()).activateMap(config);
  } catch {
    document.getElementById('map-status').textContent = 'Peta belum berhasil dimuat. Coba lagi atau buka peta lengkap.';
  } finally { button.disabled = false; }
});
// The observer triggers on actual proximity, not an arbitrary timer.
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    if (entries.some(entry => entry.isIntersecting)) {
      observer.disconnect();
      loadSummary();
    }
  }, { rootMargin: '100px' });
  observer.observe(document.getElementById('pohon'));
} else {
  loadSummary();
}
// Preserve older root hash links when the former Flutter entry was at /.
if (/^#\/(peta|permohonan|statistik|tentang|lacak|login)(\?|$)/.test(location.hash)) {
  location.replace('/app/' + location.hash);
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(registrations => {
    for (const registration of registrations) {
      const script = registration.active?.scriptURL || registration.waiting?.scriptURL || registration.installing?.scriptURL;
      if (script && new URL(script).pathname === '/flutter_service_worker.js') registration.unregister();
    }
  }).catch(() => {});
}
