{{flutter_js}}
{{flutter_build_config}}

// The build preparation tool enables this only for a complete production shell.
const miseOfflineBuild = false;
if (miseOfflineBuild && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register(new URL('offline_worker.js', document.baseURI), {
      scope: new URL('.', document.baseURI).pathname,
      updateViaCache: 'none',
    }).catch(() => { /* The app remains usable if the browser refuses caching. */ });
  });
}

_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  },
});
