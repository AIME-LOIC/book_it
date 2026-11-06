import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'firebase_options.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static final StreamController<Map<String, dynamic>> _opened = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get openedMessages => _opened.stream;
  static bool _initialized = false;
  static bool _initializing = false;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'bookit_updates',
    'BookIt updates',
    description: 'Booking, trip and account updates from BookIt.',
    importance: Importance.high,
  );

  static Future<void> registerDevice() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS) || !DefaultFirebaseOptions.isConfigured) return;
    if (_initializing) return;
    _initializing = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      if (!_initialized) {
        const settings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );
        await _local.initialize(
          settings,
          onDidReceiveNotificationResponse: (response) {
            final raw = response.payload;
            if (raw == null || raw.isEmpty) return;
            try {
              final decoded = jsonDecode(raw);
              if (decoded is Map) _opened.add(Map<String, dynamic>.from(decoded));
            } catch (_) {}
          },
        );
        final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(_channel);
        FirebaseMessaging.onMessage.listen(_showForegroundNotification);
        FirebaseMessaging.onMessageOpenedApp.listen((message) => _opened.add(message.data));
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _opened.add(initial.data);
        FirebaseMessaging.instance.onTokenRefresh.listen((token) => _sendToken(token));
        _initialized = true;
      }
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _sendToken(token);
    } catch (error) {
      debugPrint('[Push] Firebase is not configured or unavailable: $error');
    } finally {
      _initializing = false;
    }
  }

  static Future<void> _sendToken(String token) async {
    if (!ApiClient.hasToken) return;
    try {
      await ApiClient.post(
        'notifications/devices',
        auth: true,
        body: {
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
    } catch (error) {
      debugPrint('[Push] Could not register device token: $error');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'BookIt update';
    final body = message.notification?.body ?? '';
    if (body.isEmpty) return;
    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
