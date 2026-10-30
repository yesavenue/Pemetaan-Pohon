let trees;
let pending;
let selected = 'all';
let map;
let layer;
let leafletPending;
const labels = { sehat: 'Sehat', sakit: 'Sakit', rawanTumbang: 'Rawan tumbang' };
const colors = { sehat: '#2e7d5b', sakit: '#b7791f', rawanTumbang: '#ad3c31' };
function value(field) { return field?.stringValue ?? field?.doubleValue ?? field?.integerValue; }
function condition(raw) {
  if (raw === 'sakit') return 'sakit';
  if (['rawanTumbang', 'rawantumbang', 'rawan_tumbang', 'rawan tumbang'].includes(raw)) return 'rawanTumbang';
  return 'sehat';
}
// Public projection only: neither photoBase64 nor any private collection is read.
// Each request still obeys Firestore security rules. No service account is used.
export async function fetchTrees(config, fetcher = fetch) {
  const result = [];
  let cursor;
  for (;;) {
    const query = {
      from: [{ collectionId: 'public_trees' }],
      select: { fields: ['latitude', 'longitude', 'condition', 'species', 'status'].map(fieldPath => ({ fieldPath })) },
      orderBy: [{ field: { fieldPath: '__name__' }, direction: 'ASCENDING' }],
      limit: 200,
    };
    if (cursor) query.startAt = { values: [{ referenceValue: cursor }], before: false };
    const response = await fetcher(`https://firestore.googleapis.com/v1/projects/${encodeURIComponent(config.projectId)}/databases/(default)/documents:runQuery?key=${encodeURIComponent(config.apiKey)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ structuredQuery: query }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error('Public data unavailable');
    const rows = await response.json();
    if (!Array.isArray(rows)) throw new Error('Invalid public response');
    const docs = rows.filter(row => row.document).map(row => row.document);
    for (const doc of docs) {
      const fields = doc.fields ?? {};
      if (value(fields.status) !== 'verified') continue;
      result.push({ id: doc.name.split('/').pop(), latitude: Number(value(fields.latitude)), longitude: Number(value(fields.longitude)), condition: condition(value(fields.condition)), species: String(value(fields.species) ?? 'Pohon') });
    }
    if (docs.length < 200) return result;
    const next = docs.at(-1).name;
    if (next === cursor) throw new Error('Pagination did not advance');
    cursor = next;
  }
}
export async function loadSummary(config, force = false) {
  if (pending) return pending;
  if (trees && !force) return trees;
  const status = document.getElementById('data-status');
  const refresh = document.getElementById('refresh-data');
  status.textContent = 'Memuat ringkasan pohon…';
  refresh.disabled = true;
  pending = fetchTrees(config).then(data => {
    trees = data;
    for (const output of document.querySelectorAll('[data-count]')) {
      const filter = output.dataset.count;
      output.textContent = new Intl.NumberFormat('id-ID').format(filter === 'all' ? trees.length : trees.filter(tree => tree.condition === filter).length);
    }
    status.textContent = `Data terverifikasi · Diperbarui ${new Intl.DateTimeFormat('id-ID', { hour: '2-digit', minute: '2-digit' }).format(new Date())}`;
    drawMarkers();
    return trees;
  }).catch(error => {
    status.textContent = trees ? 'Pembaruan gagal. Ringkasan terakhir tetap ditampilkan; coba lagi.' : 'Ringkasan belum tersedia. Tekan Perbarui data untuk mencoba lagi.';
    throw error;
  }).finally(() => { pending = undefined; refresh.disabled = false; });
  return pending;
}
export function selectCondition(filter) {
  selected = filter;
  for (const button of document.querySelectorAll('[data-condition]')) {
    const active = button.dataset.condition === filter;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  }
  drawMarkers();
}
async function loadLeaflet(config) {
  if (window.L) return;
  if (leafletPending) return leafletPending;
  leafletPending = Promise.all([
    new Promise((resolve, reject) => {
      const link = document.createElement('link'); link.rel = 'stylesheet'; link.href = config.leafletCss;
      link.onload = resolve; link.onerror = () => { link.remove(); reject(new Error('Map style unavailable')); };
      document.head.append(link);
    }),
    new Promise((resolve, reject) => {
      const script = document.createElement('script'); script.src = config.leafletJs;
      script.onload = resolve; script.onerror = () => { script.remove(); reject(new Error('Map unavailable')); };
      document.head.append(script);
    }),
  ]).catch(error => { leafletPending = undefined; throw error; });
  return leafletPending;
}
export async function activateMap(config) {
  const [data] = await Promise.all([loadSummary(config), loadLeaflet(config)]);
  if (!map) {
    map = window.L.map('map', { scrollWheelZoom: false }).setView([-6.732, 108.552], 12);
    window.L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).on('tileerror', () => {
      document.getElementById('data-status').textContent = 'Sebagian latar peta belum termuat. Penanda dan tautan peta lengkap tetap tersedia.';
    }).addTo(map);
    layer = window.L.layerGroup().addTo(map);
  }
  document.getElementById('map-placeholder').hidden = true;
  map.invalidateSize();
  drawMarkers();
  document.getElementById('map').tabIndex = 0;
  document.getElementById('map').focus({ preventScroll: true });
  return data;
}
function drawMarkers() {
  if (!layer || !trees) return;
  layer.clearLayers();
  const visible = trees.filter(tree => (selected === 'all' || tree.condition === selected) && Number.isFinite(tree.latitude) && Number.isFinite(tree.longitude) && Math.abs(tree.latitude) <= 90 && Math.abs(tree.longitude) <= 180);
  const points = [];
  for (const tree of visible) {
    const popup = document.createElement('div');
    const title = document.createElement('strong'); title.textContent = tree.species;
    const state = document.createElement('p'); state.textContent = labels[tree.condition];
    const link = document.createElement('a'); link.textContent = 'Lihat detail pohon'; link.href = '/app/#/peta?tree=' + encodeURIComponent(tree.id);
    popup.append(title, state, link);
    const point = [tree.latitude, tree.longitude]; points.push(point);
    const marker = window.L.circleMarker(point, { radius: 7, weight: 2, color: '#fff', fillColor: colors[tree.condition], fillOpacity: 1 }).bindPopup(popup).addTo(layer);
    const element = marker.getElement();
    if (element) {
      element.setAttribute('tabindex', '0');
      element.setAttribute('role', 'button');
      element.setAttribute('aria-label', `${tree.species}, ${labels[tree.condition]}. Buka informasi pohon.`);
      element.addEventListener('keydown', event => {
        if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); marker.openPopup(); }
      });
    }
  }
  if (points.length) map.fitBounds(points, { padding: [24, 24], maxZoom: 15 });
  document.getElementById('map').setAttribute('aria-label', `Pratinjau peta: ${visible.length} pohon dengan koordinat tersedia. Detail juga dapat diakses melalui peta lengkap.`);
  if (!points.length) document.getElementById('data-status').textContent = 'Belum ada koordinat pohon untuk kondisi yang dipilih.';
}
