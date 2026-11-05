// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;

Future<bool> isWebNotificationSupported() async {
  try {
    return js.context.callMethod('isNotificationSupported') == true;
  } catch (_) {
    return false;
  }
}

Future<String> getWebNotificationPermission() async {
  try {
    final result = js.context.callMethod('getNotificationPermission');
    return result?.toString() ?? 'unsupported';
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestWebNotificationPermission() async {
  final completer = Completer<String>();
  try {
    js.context.callMethod('requestNotificationPermissionAsync', [
      js.allowInterop((dynamic perm) {
        completer.complete(perm?.toString() ?? 'denied');
      })
    ]);
  } catch (_) {
    completer.complete('denied');
  }
  return completer.future;
}

void showWebNotification({
  required String title,
  String? body,
  String? tag,
  String? icon,
  String? url,
}) {
  try {
    js.context.callMethod('showWebPushNotification', [
      title,
      body ?? '',
      tag ?? '',
      icon ?? 'favicon.png',
      url ?? '',
    ]);
  } catch (_) {}
}
