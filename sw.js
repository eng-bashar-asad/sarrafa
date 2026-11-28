// Page and app code: network first (bypassing the HTTP cache so updates show at once), but give up after 4 s and use the
// saved copy so a slow connection never blocks opening. Big fixed files (supabase library, logo): saved copy first,
// refreshed in the background. Data always comes live from Supabase.
const CACHE = "sarrafa-v32";
self.addEventListener("install", e => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => clients.claim())));
const save = (req, r) => { if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return r; };
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return;
  const net = fetch(e.request, {cache: "no-cache"}).then(r => save(e.request, r));
  if (/\/(vendor|brand)\//.test(url.pathname)) {
    e.respondWith(caches.match(e.request).then(hit => { if (hit) { e.waitUntil(net.catch(() => {})); return hit; } return net; }));
    return;
  }
  e.respondWith(caches.match(e.request, {ignoreSearch: true}).then(hit => !hit ? net :
    Promise.race([net.catch(() => hit), new Promise(res => setTimeout(() => res(hit), 4000))])));
});
