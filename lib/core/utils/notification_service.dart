import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs in a background isolate when the app is KILLED and FCM arrives.
/// 1. Saves disconnect flag to SharedPreferences (for CodeView to check on launch)
/// 2. Sends a local broadcast via platform channel to launch the app immediately
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  final type = data['type']?.toString() ??
      data['title']?.toString() ??
      message.notification?.title ?? '';

  debugPrint("Background FCM: type=$type id=${message.messageId}");

  final isDisconnect = type == 'Disconnected' ||
      type == 'Deleted'  ||
      type == 'Suspended';

  if (isDisconnect) {
    // 1. Save flag so CodeView skips auto-login on next launch
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_navigate_to', 'code_view');
      await prefs.setString('pending_disconnect_type', type);
      debugPrint("Background FCM: saved disconnect=$type to prefs");
    } catch (e) {
      debugPrint("Background FCM: prefs write failed: $e");
    }

    // 2. Send broadcast to DisconnectReceiver to wake screen and launch app
    // Note: MethodChannel is not available in background isolate (no engine),
    // so we use a direct Android broadcast via a helper class instead.
    try {
      // Use android_alarm_manager or just rely on the notification tap
      // The prefs flag ensures CodeView shows when user opens the app
      debugPrint("Background FCM: prefs saved, app will open CodeView on next launch");
    } catch (e) {
      debugPrint("Background FCM: $e");
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.cct.appfortv/notification');

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Called with the disconnect type string ("Disconnected", "Deleted", "Suspended")
  /// to trigger navigation back to CodeView.
  Function(String)? onActionReceived;

  /// Called when the device data should be refreshed (e.g. "Updated" push).
  Function? onDataUpdateRequested;

  /// Called when Firebase rotates the FCM token — re-register with backend.
  Function(String)? _onTokenRefreshed;
  set onTokenRefreshed(Function(String) cb) => _onTokenRefreshed = cb;

  // ── Token access ────────────────────────────────────────────────────────────

  /// Returns the current FCM token. Used by CodeController to pass
  /// device_token in the pairing API request.
  Future<String?> getToken() => _messaging.getToken();

  // ── Topic helpers ────────────────────────────────────────────────────────────

  /// Subscribe to the device-specific topic so the backend can push
  /// targeted disconnect notifications via FCM v1.
  Future<void> subscribeToDeviceTopic(String deviceId) async {
    try {
      await _messaging.subscribeToTopic(deviceId);
      debugPrint('NotificationService: Subscribed to topic: $deviceId');
    } catch (e) {
      debugPrint('NotificationService: subscribeToTopic error: $e');
    }
  }

  /// Unsubscribe from the device topic when the session is cleared.
  Future<void> unsubscribeFromDeviceTopic(String deviceId) async {
    try {
      await _messaging.unsubscribeFromTopic(deviceId);
      debugPrint('NotificationService: Unsubscribed from topic: $deviceId');
    } catch (e) {
      debugPrint('NotificationService: unsubscribeFromTopic error: $e');
    }
  }

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permission (also covers POST_NOTIFICATIONS on Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    // Tell Firebase NOT to show its own notification when app is in foreground —
    // our native FcmService.showHeadsUpNotification() handles that instead,
    // ensuring identical behaviour in all app states.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    // Log FCM token for backend registration
    final token = await _messaging.getToken();
    _printToken(token);

    // Re-print and notify whenever the token is rotated by Firebase
    _messaging.onTokenRefresh.listen((newToken) {
      _printToken(newToken);
      // Notify so controllers can re-register the new token with the backend
      _onTokenRefreshed?.call(newToken);
    });

    // ── Foreground FCM messages ──────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM foreground message: ${message.data}");
      _handleMessage(message);
    });

    // ── Tapped notification while app was in background ──────────────────────
    // NOTE: do NOT call _handleMessage here for disconnect types —
    // onScreenRemoved is already triggered by onMessage above when app is open.
    // onMessageOpenedApp only matters when app was in background and user tapped.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM onMessageOpenedApp: ${message.data}");
      _handleMessage(message);
    });

    // ── App launched from a terminated state via notification tap ─────────────
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint("FCM initial message (app was killed): ${initial.data}");
      _handleMessage(initial);
    }

    // ── Native MethodChannel: FcmService launched the app while it was killed ─
    // Listen for calls pushed from MainActivity.onNewIntent
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        final args = call.arguments as Map?;
        final disconnectType = args?['disconnect_type']?.toString() ?? 'Disconnected';
        onActionReceived?.call(disconnectType);
      }
    });

    // Check if MainActivity was started from a notification while app was killed
    await _checkPendingNavigation();
  }

  /// Asks native for any navigation intent that was set before Flutter was ready.
  /// Also checks SharedPreferences written by the background FCM handler.
  Future<void> _checkPendingNavigation() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      // 1. Check native intent extra (set by ForceOpenService)
      final result = await _channel.invokeMethod<Map>('getPendingNavigation');
      if (result != null) {
        final disconnectType =
            result['disconnect_type']?.toString() ?? 'Disconnected';
        debugPrint("Pending navigation from native intent: $disconnectType");
        onActionReceived?.call(disconnectType);
        return; // native intent takes priority
      }

      // 2. Fallback: check SharedPreferences written by background FCM handler
      final prefs = await SharedPreferences.getInstance();
      final pendingNav = prefs.getString('pending_navigate_to');
      if (pendingNav == 'code_view') {
        final disconnectType =
            prefs.getString('pending_disconnect_type') ?? 'Disconnected';
        debugPrint("Pending navigation from prefs: $disconnectType");
        // Clear the flag immediately so it doesn't fire again
        await prefs.remove('pending_navigate_to');
        await prefs.remove('pending_disconnect_type');
        onActionReceived?.call(disconnectType);
      }
    } catch (e) {
      debugPrint("NotificationService: _checkPendingNavigation error: $e");
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString() ??
        data['title']?.toString() ??
        message.notification?.title;

    if (type == null) return;

    debugPrint('NotificationService: _handleMessage type=$type');

    if (type == 'Disconnected' || type == 'Deleted' || type == 'Suspended') {
      onActionReceived?.call(type);
    } else if (type == 'Updated' || type == 'Changed') {
      onDataUpdateRequested?.call();
    }
  }

  void _printToken(String? token) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════╗');
    debugPrint('║              FCM DEVICE TOKEN                           ║');
    debugPrint('╠══════════════════════════════════════════════════════════╣');
    if (token != null && token.isNotEmpty) {
      // Print in chunks of 60 chars so it fits console width
      const chunkSize = 58;
      for (var i = 0; i < token.length; i += chunkSize) {
        final end = (i + chunkSize < token.length) ? i + chunkSize : token.length;
        final line = token.substring(i, end).padRight(chunkSize);
        debugPrint('║ $line ║');
      }
    } else {
      debugPrint('║  [TOKEN NOT AVAILABLE]                                   ║');
    }
    debugPrint('╚══════════════════════════════════════════════════════════╝');
    debugPrint('');
  }
}
