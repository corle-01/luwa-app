import 'dart:js_interop';
import 'package:web/web.dart' as web;

// ---------------------------------------------------------------------------
// Browser Notification API service for self-order tracking.
//
// Uses `package:web` (same pattern as `lib/shared/services/export_download_web.dart`)
// to interface with the browser Notification API.
//
// Falls back gracefully on platforms where Notification is unavailable.
// ---------------------------------------------------------------------------

/// Checks whether the Notification API is available in the current browser.
bool isNotificationSupported() {
  try {
    // Attempt to read Notification.permission; if it throws, API is missing.
    web.Notification.permission;
    return true;
  } catch (_) {
    return false;
  }
}

/// Checks the current notification permission status.
/// Returns 'granted', 'denied', or 'default'.
String getNotificationPermission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'denied';
  }
}

/// Requests notification permission from the user.
/// Returns a Future that resolves to the permission string
/// ('granted', 'denied', or 'default').
Future<String> requestNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart;
  } catch (_) {
    return 'denied';
  }
}

/// Shows a browser notification with the given [title] and optional [body].
/// Returns true if the notification was shown, false otherwise.
///
/// Uses `requireInteraction: true` so the notification persists until
/// the customer interacts with it. The `tag` field prevents duplicates
/// (a new notification with the same tag replaces the old one).
bool showBrowserNotification(String title, String body) {
  if (getNotificationPermission() != 'granted') return false;
  try {
    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: 'icons/Icon-192.png',
        tag: 'order-ready',
        requireInteraction: true,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
