import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'web_notification_service.dart';

// Top-level handler untuk pesan background di Android
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AppNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pump_critical_channel',
    'Peringatan Kritis Pompa',
    description: 'Notifikasi saat parameter motor/pompa abnormal',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize() async {
    if (kIsWeb) {
      // Jika di web browser, pakai universal_html
      await WebNotificationService.requestPermission();
    } else {
      // Jika di Android (Mobile App)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Inisialisasi Android Local Notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(initSettings);

      // Buat notification channel di Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Minta izin runtime (Android 13+)
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Simpan Token FCM perangkat ke Realtime Database
      try {
        final String? token = await messaging.getToken();
        if (token != null) {
          // Token disimpan agar backend/Cloud Functions tahu ke mana harus push
          final String cleanKey = token.replaceAll(RegExp(r'[.#$\[\]]'), '_');
          await FirebaseDatabase.instance
              .ref('fcm_tokens/$cleanKey')
              .set({'token': token, 'platform': 'android', 'updated_at': ServerValue.timestamp});
        }
      } catch (e) {
        debugPrint('Gagal mengambil/menyimpan FCM token: $e');
      }

      // Tampilkan notifikasi jika aplikasi sedang terbuka (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showNotification(
            title: notification.title ?? 'Peringatan Pompa',
            body: notification.body ?? 'Kondisi anomali terdeteksi',
          );
        }
      });
    }
  }

  // Fungsi universal pemanggil popup notifikasi
  static void showNotification({
    required String title,
    required String body,
  }) {
    if (kIsWeb) {
      WebNotificationService.show(title: title, body: body);
    } else {
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    }
  }
}