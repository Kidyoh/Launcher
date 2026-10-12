import 'package:flutter/material.dart';

import '../apps.dart';
import '../native.dart';
import '../scope.dart';
import '../settings.dart';

/// The long-press menu for an app.
Future<void> showAppActions(BuildContext context, AppEntry app) {
  final scope = Launcher.of(context);
  final settings = scope.settings;
  final favorite = settings.isFavorite(app.key);
  final hidden = settings.hidden.contains(app.key);

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      Widget item(String text, VoidCallback onTap) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        title: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
        ),
        onTap: () {
          Navigator.pop(sheet);
          onTap();
        },
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
                child: Text(
                  scope.apps.labelOf(app),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
              item(favorite ? 'Remove from home' : 'Add to home', () {
                if (favorite) {
                  settings.removeFavorite(app.key);
                } else if (settings.favoritesFull) {
                  toast(
                    context,
                    'Home holds up to ${Settings.maxFavorites} apps',
                  );
                } else {
                  settings.addFavorite(app.key);
                }
              }),
              item('Rename', () => renameApp(context, app)),
              item(
                hidden ? 'Unhide' : 'Hide',
                () => settings.setHidden(app.key, !hidden),
              ),
              item('App info', () => Native.appInfo(app)),
              item('Uninstall', () => Native.uninstall(app)),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> renameApp(BuildContext context, AppEntry app) async {
  final scope = Launcher.of(context);
  final controller = TextEditingController(text: scope.apps.labelOf(app));
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: app.label),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name != null) scope.settings.rename(app.key, name);
}
