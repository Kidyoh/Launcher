import 'package:flutter/services.dart';

import 'apps.dart';

/// Thin wrapper over the Kotlin side (MainActivity.kt).
class Native {
  static const _channel = MethodChannel('launcher/native');

  static VoidCallback? onAppsChanged;
  static VoidCallback? onHome;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'appsChanged':
          onAppsChanged?.call();
        case 'home':
          onHome?.call();
      }
    });
  }

  static Future<List<AppEntry>> getApps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'getApps',
    );
    return [for (final m in raw ?? const []) AppEntry.fromMap(m)];
  }

  static Future<bool> launch(AppEntry app) => _call('launch', app.args);

  static Future<bool> appInfo(AppEntry app) => _call('appInfo', app.args);

  static Future<bool> uninstall(AppEntry app) => _call('uninstall', app.args);

  static Future<bool> expandNotifications() => _call('expandNotifications');

  static Future<bool> isDefaultLauncher() => _call('isDefaultLauncher');

  /// One of: ok, needs_permission, unsupported, failed.
  static Future<String> lockScreen() async =>
      await _channel.invokeMethod<String>('lockScreen') ?? 'failed';

  /// [target] is one of: dialer, camera, alarms, calendar, webSearch,
  /// accessibility, homeSettings.
  static Future<bool> open(String target, {String? query}) =>
      _call('open', {'target': target, 'query': query});

  static Future<bool> _call(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on PlatformException {
      return false;
    }
  }
}
