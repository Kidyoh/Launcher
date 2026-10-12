import 'package:flutter/material.dart';

import '../native.dart';
import '../scope.dart';
import '../settings.dart';
import 'app_picker.dart';
import 'gestures.dart';

Future<void> openSettings(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isDefault = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDefault();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have just picked a home app in system settings.
    if (state == AppLifecycleState.resumed) _checkDefault();
  }

  Future<void> _checkDefault() async {
    final isDefault = await Native.isDefaultLauncher();
    if (mounted) setState(() => _isDefault = isDefault);
  }

  Future<void> _pickGesture(Gesture gesture) async {
    final scope = Launcher.of(context);
    final current = scope.settings.gesture(gesture);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final MapEntry(:key, :value) in builtInActions.entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                  title: Text(value),
                  trailing: current == key ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheet, key),
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                title: const Text('Open an app…'),
                trailing: current.startsWith('app:')
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheet, 'app:'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'app:') {
      final app = await pickApp(context, title: gestureNames[gesture]!);
      if (app != null) scope.settings.setGesture(gesture, 'app:${app.key}');
    } else {
      scope.settings.setGesture(gesture, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = Launcher.of(context);
    final s = scope.settings;
    final apps = scope.apps;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: apps,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (!_isDefault)
              ListTile(
                title: const Text('Make this your home screen'),
                subtitle: const Text('Choose Launcher as the default home app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Native.requestDefaultLauncher();
                  await _checkDefault();
                },
              ),
            const _Header('Home'),
            ListTile(
              title: const Text('Home apps'),
              subtitle: Text(
                '${s.favorites.length} of ${Settings.maxFavorites}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _FavoritesScreen()),
              ),
            ),
            SwitchListTile(
              title: const Text('Show clock'),
              value: s.showClock,
              onChanged: (v) => s.showClock = v,
            ),
            SwitchListTile(
              title: const Text('Show date'),
              value: s.showDate,
              onChanged: (v) => s.showDate = v,
            ),
            SwitchListTile(
              title: const Text('Show status bar'),
              value: s.showStatusBar,
              onChanged: (v) => s.showStatusBar = v,
            ),
            const _Header('Look'),
            _Choices<ThemeChoice>(
              label: 'Theme',
              value: s.theme,
              options: const {
                ThemeChoice.black: 'Black',
                ThemeChoice.dark: 'Dark',
                ThemeChoice.light: 'Light',
                ThemeChoice.system: 'System',
              },
              onChanged: (v) => s.theme = v,
            ),
            _Choices<HomeAlign>(
              label: 'Alignment',
              value: s.align,
              options: const {
                HomeAlign.start: 'Left',
                HomeAlign.center: 'Center',
                HomeAlign.end: 'Right',
              },
              onChanged: (v) => s.align = v,
            ),
            ListTile(
              title: const Text('Text size'),
              subtitle: Slider(
                value: s.textScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(s.textScale * 100).round()}%',
                onChanged: (v) => s.textScale = v,
              ),
            ),
            const _Header('All apps'),
            SwitchListTile(
              title: const Text('Open keyboard right away'),
              value: s.drawerKeyboard,
              onChanged: (v) => s.drawerKeyboard = v,
            ),
            SwitchListTile(
              title: const Text('Open single match'),
              subtitle: const Text(
                'Opens the app as soon as the search narrows to one',
              ),
              value: s.autoLaunch,
              onChanged: (v) => s.autoLaunch = v,
            ),
            ListTile(
              title: const Text('Hidden apps'),
              subtitle: Text('${apps.hiddenApps.length}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _HiddenAppsScreen()),
              ),
            ),
            const _Header('Gestures'),
            for (final g in Gesture.values)
              ListTile(
                title: Text(gestureNames[g]!),
                subtitle: Text(actionLabel(s.gesture(g), apps)),
                onTap: () => _pickGesture(g),
              ),
            const ListTile(title: Text('Swipe up'), subtitle: Text('All apps')),
            const ListTile(
              title: Text('Long-press'),
              subtitle: Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1.6,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    ),
  );
}

/// A row of words; the chosen one is bright, the rest are faded.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      title: Text(label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 20,
          children: [
            for (final MapEntry(:key, value: name) in options.entries)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: key == value
                          ? FontWeight.w600
                          : FontWeight.w300,
                      color: key == value
                          ? color
                          : color.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesScreen extends StatelessWidget {
  const _FavoritesScreen();

  @override
  Widget build(BuildContext context) {
    final scope = Launcher.of(context);
    final s = scope.settings;
    final apps = scope.apps;

    return ListenableBuilder(
      listenable: apps,
      builder: (context, _) {
        // Keys, not apps, so uninstalled favorites can still be removed.
        final keys = s.favorites;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Home apps'),
            actions: [
              IconButton(
                tooltip: 'Add app',
                icon: const Icon(Icons.add),
                onPressed: s.favoritesFull
                    ? null
                    : () async {
                        final app = await pickApp(
                          context,
                          title: 'Add to home',
                        );
                        if (app != null) s.addFavorite(app.key);
                      },
              ),
            ],
          ),
          body: keys.isEmpty
              ? const Center(child: Text('Tap + to add up to 8 apps.'))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: keys.length,
                  onReorderItem: s.moveFavorite,
                  itemBuilder: (context, i) {
                    final app = apps.byKey(keys[i]);
                    return ListTile(
                      key: ValueKey(keys[i]),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(
                        app == null ? 'Not installed' : apps.labelOf(app),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () => s.removeFavorite(keys[i]),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _HiddenAppsScreen extends StatelessWidget {
  const _HiddenAppsScreen();

  @override
  Widget build(BuildContext context) {
    final scope = Launcher.of(context);
    final apps = scope.apps;

    return Scaffold(
      appBar: AppBar(title: const Text('Hidden apps')),
      body: ListenableBuilder(
        listenable: apps,
        builder: (context, _) {
          final hidden = apps.hiddenApps;
          if (hidden.isEmpty) {
            return const Center(
              child: Text('Long-press an app and choose Hide.'),
            );
          }
          return ListView(
            children: [
              for (final app in hidden)
                ListTile(
                  title: Text(apps.labelOf(app)),
                  onTap: () => launchApp(context, app),
                  trailing: TextButton(
                    onPressed: () => scope.settings.setHidden(app.key, false),
                    child: const Text('Unhide'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
