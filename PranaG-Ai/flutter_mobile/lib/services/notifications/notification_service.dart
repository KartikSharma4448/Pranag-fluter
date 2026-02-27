import "dart:io";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:cloud_firestore/cloud_firestore.dart";

import "../firebase/firebase_service.dart";

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = "pranag_alerts";
  static const String _channelName = "PRANA-G Alerts";

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (!isMobile) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings("@mipmap/ic_launcher");
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _local.initialize(initSettings);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: "Alerts for latest cattle health updates",
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await _requestPermissions();
    _listenToForegroundMessages();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final messaging = FirebaseService.instance.messaging;
    if (messaging == null) return;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _showLocalNotification(
        title: notification.title ?? "PRANA-G Alert",
        body: notification.body ?? "New alert received.",
      );
    });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> showAlertNotification({
    required String title,
    required String body,
  }) async {
    await _showLocalNotification(title: title, body: body);
  }

  Future<void> registerDeviceToken({required String uid}) async {
    final messaging = FirebaseService.instance.messaging;
    final firestore = FirebaseService.instance.firestore;
    if (messaging == null) return;

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;

    await firestore.collection("users").doc(uid).set({
      "deviceTokens": {token: true},
      "updatedAt": DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }
}
