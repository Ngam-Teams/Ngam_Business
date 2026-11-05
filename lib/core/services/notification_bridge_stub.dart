// Stub implementation for mobile and desktop native platforms
Future<bool> isWebNotificationSupported() async => false;

Future<String> getWebNotificationPermission() async => 'unsupported';

Future<String> requestWebNotificationPermission() async => 'unsupported';

void showWebNotification({
  required String title,
  String? body,
  String? tag,
  String? icon,
  String? url,
}) {}
