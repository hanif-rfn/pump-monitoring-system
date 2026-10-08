import 'package:universal_html/html.dart' as html;

class WebNotificationService {
  static Future<void> requestPermission() async {
    if (html.Notification.supported) {
      if (html.Notification.permission != 'granted') {
        await html.Notification.requestPermission();
      }
    }
  }

  static void show({
    required String title,
    required String body,
  }) {
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: 'assets/ic.png',
      );
    }
  }
}