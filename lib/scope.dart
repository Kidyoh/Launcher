import 'package:flutter/material.dart';

import 'apps.dart';
import 'native.dart';
import 'settings.dart';

/// Gives every screen access to the settings and the app list. Screens
/// rebuild by listening to [apps], which also fires when settings change.
class Launcher extends InheritedWidget {
  const Launcher({
    super.key,
    required this.settings,
    required this.apps,
    required super.child,
  });

  final Settings settings;
  final AppRepository apps;

  static Launcher of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Launcher>()!;

  @override
  bool updateShouldNotify(Launcher oldWidget) =>
      settings != oldWidget.settings || apps != oldWidget.apps;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

Future<bool> launchApp(BuildContext context, AppEntry app) async {
  final ok = await Native.launch(app);
  if (!ok && context.mounted) {
    toast(context, "Couldn't open ${Launcher.of(context).apps.labelOf(app)}");
  }
  return ok;
}
