{{flutter_js}}
{{flutter_build_config}}

// Serve Flutter's renderer with the app instead of fetching it from a CDN.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
}).catch((error) => {
  console.error('Unable to start LEARNsync.', error);
  const message = document.createElement('p');
  message.textContent = 'LEARNsync could not start. Please refresh the page.';
  message.setAttribute('role', 'alert');
  message.style.cssText = 'position:fixed;bottom:24px;left:24px;right:24px;text-align:center;font:16px sans-serif;color:#0B2545';
  document.body.append(message);
});
