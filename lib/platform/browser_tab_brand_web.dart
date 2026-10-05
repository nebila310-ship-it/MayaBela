import 'package:web/web.dart' as web;

void applyBrowserTabBrand({
  String? title,
  String? iconDataUrl,
  String? iconUrl,
}) {
  try {
    final name = title?.trim();
    if (name != null && name.isNotEmpty) {
      web.document.title = name;
      web.document
          .querySelector('meta[name="apple-mobile-web-app-title"]')
          ?.setAttribute('content', name);
    }
    final href = (iconDataUrl != null && iconDataUrl.trim().isNotEmpty)
        ? iconDataUrl.trim()
        : iconUrl?.trim();
    if (href == null || href.isEmpty) return;

    var icon = web.document.querySelector('link[rel="icon"]');
    if (icon == null) {
      icon = web.document.createElement('link');
      icon.setAttribute('rel', 'icon');
      web.document.head?.append(icon);
    }
    icon.setAttribute('href', href);
    if (href.startsWith('data:image')) {
      icon.setAttribute('type', 'image/jpeg');
    }

    final apple = web.document.querySelector('link[rel="apple-touch-icon"]');
    apple?.setAttribute('href', href);
  } catch (_) {}
}
