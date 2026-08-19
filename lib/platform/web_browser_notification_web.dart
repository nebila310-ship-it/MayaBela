import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> showWebBrowserNotification({
  required String title,
  required String body,
}) async {
  try {
    var permission = web.Notification.permission;
    if (permission != 'granted') {
      permission =
          (await web.Notification.requestPermission().toDart).toDart;
      if (permission != 'granted') return false;
    }
    web.Notification(title, web.NotificationOptions(body: body));
    return true;
  } catch (_) {
    // Browser without Notification support (or permission API failure).
    return false;
  }
}
