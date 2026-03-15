// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── Background message handler (must be top-level function) ───────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Navigation key — set this in main.dart so we can navigate from notifications
  static GlobalKey<NavigatorState>? navigatorKey;

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'qotd_channel',
    'Question of the Day',
    description: 'Daily question notifications from PrepNG',
    importance: Importance.high,
  );

  // ─── Initialize everything ──────────────────────────────────────────────
  Future<void> initialize() async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission denied');
      return;
    }

    // 2. Set up local notifications (needed for foreground display on Android)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 3. Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Save FCM token to Firestore
    await _saveToken();

    // 5. Listen for token refresh
    _fcm.onTokenRefresh.listen(_updateToken);

    // 6. Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 7. Handle notification tap when app is in background (but open)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 8. Check if app was launched from a notification tap
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }

    // 9. Set foreground notification presentation options (iOS)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('NotificationService initialized successfully');
  }

  // ─── Save FCM token to Firestore ────────────────────────────────────────
  Future<void> _saveToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _fcm.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('FCM token saved: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _updateToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // ─── Handle foreground message ───────────────────────────────────────────
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Encode type + date into payload so the tap handler can read both
    // Format: "qotd|2026-03-28"
    final date = message.data['date'] as String? ?? '';
    final payload = 'qotd|$date';

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ─── Handle tap on local notification (foreground) ──────────────────────
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    final parts = payload.split('|');
    final type = parts.isNotEmpty ? parts[0] : '';
    final date = parts.length > 1 ? parts[1] : '';

    if (type == 'qotd') {
      Future.delayed(
        const Duration(milliseconds: 300),
        () => _navigateToQOTD(date: date.isNotEmpty ? date : null),
      );
    }
  }

  // ─── Handle tap when app is in background ───────────────────────────────
  void _onMessageOpenedApp(RemoteMessage message) {
    _handleNotificationNavigation(message.data);
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    if (data['type'] == 'qotd') {
      final date = data['date'] as String?;
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _navigateToQOTD(date: date),
      );
    }
  }

  // ─── Navigate to QOTD screen passing the date from the notification ──────
  // The screen reads this via ModalRoute.of(context)?.settings.arguments
  // and uses it to look up the correct Firestore document instead of today's.
  void _navigateToQOTD({String? date}) {
    navigatorKey?.currentState?.pushNamed(
      '/qotd',
      arguments: date,
    );
  }

  // ─── Call this after user logs in to save token ──────────────────────────
  Future<void> onUserLogin() async {
    await _saveToken();
  }

  // ─── Call this after user logs out to clear token ───────────────────────
  Future<void> onUserLogout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': FieldValue.delete()});
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }
}