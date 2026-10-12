import 'package:flutter/material.dart';

import '../apps.dart';
import '../native.dart';
import '../scope.dart';
import '../settings.dart';
import 'drawer_screen.dart';

/// Built-in gesture actions. A gesture can also open an app: `app:<key>`.
const builtInActions = {
  'none': 'Do nothing',
  'phone': 'Phone',
  'camera': 'Camera',
  'notifications': 'Notifications',
  'lock': 'Lock screen',
  'drawer': 'All apps',
};

const gestureNames = {
  Gesture.swipeLeft: 'Swipe left',
  Gesture.swipeRight: 'Swipe right',
  Gesture.swipeDown: 'Swipe down',
  Gesture.doubleTap: 'Double tap',
};

String actionLabel(String action, AppRepository apps) {
  if (action.startsWith('app:')) {
    final app = apps.byKey(action.substring(4));
    return app == null ? 'App not installed' : apps.labelOf(app);
  }
  return builtInActions[action] ?? builtInActions['none']!;
}

Future<void> runGesture(BuildContext context, Gesture gesture) async {
  final scope = Launcher.of(context);
  final action = scope.settings.gesture(gesture);
  switch (action) {
    case 'phone':
      await Native.open('dialer');
    case 'camera':
      await Native.open('camera');
    case 'notifications':
      await Native.expandNotifications();
    case 'lock':
      await lockScreen(context);
    case 'drawer':
      await Navigator.of(context).push(DrawerScreen.route());
    default:
      if (action.startsWith('app:')) {
        final app = scope.apps.byKey(action.substring(4));
        if (app != null) await launchApp(context, app);
      }
  }
}

Future<void> lockScreen(BuildContext context) async {
  final result = await Native.lockScreen();
  if (!context.mounted) return;
  switch (result) {
    case 'needs_permission':
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Double tap to lock'),
          content: const Text(
            'Android only lets a launcher lock the screen through an '
            'accessibility service.\n\n'
            'On the next screen, turn on "Launcher: double tap to lock". '
            'It does not read anything on your screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (open == true) await Native.open('accessibility');
    case 'unsupported':
      toast(context, 'Locking needs Android 9 or newer');
    case 'failed':
      toast(context, "Couldn't lock the screen");
  }
}
