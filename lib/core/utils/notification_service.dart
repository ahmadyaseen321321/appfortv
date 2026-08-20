import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  Function(String)? onActionReceived;
  Function? onDataUpdateRequested;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission for push notifications
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token for debugging or server-side registration
    String? token = await _messaging.getToken();
    debugPrint("FCM Token: $token");

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Message received: ${message.data}");
      _handleMessage(message);
    });

    // Listen for messages when app is in background but opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString() ?? 
                 data['title']?.toString() ?? 
                 message.notification?.title;

    if (type == "Disconnected" || type == "Deleted" || type == "Suspended") {
      onActionReceived?.call(type!);
    } else if (type == "Updated" || type == "Changed") {
      onDataUpdateRequested?.call();
    }
  }
}
