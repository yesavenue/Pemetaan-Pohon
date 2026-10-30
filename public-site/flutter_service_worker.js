// Retire the previous Flutter worker at / without touching the new /app/ scope.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    await self.registration.unregister();
    const tabs = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const tab of tabs) {
      const url = new URL(tab.url);
      if (url.origin === self.location.origin && url.pathname === '/') await tab.navigate(tab.url);
    }
  })());
});
