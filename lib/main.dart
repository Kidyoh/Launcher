import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apps.dart';
import 'native.dart';
import 'scope.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Native.init();
  final settings = await Settings.load();
  final apps = AppRepository(settings);
  Native.onAppsChanged = apps.refresh;
  runApp(Launcher(settings: settings, apps: apps, child: const LauncherApp()));
  apps.refresh();
}

class LauncherApp extends StatefulWidget {
  const LauncherApp({super.key});

  @override
  State<LauncherApp> createState() => _LauncherAppState();
}

class _LauncherAppState extends State<LauncherApp> {
  final _navigator = GlobalKey<NavigatorState>();
  bool? _statusBarShown;

  @override
  void initState() {
    super.initState();
    // Pressing home while already home closes the drawer, settings, dialogs.
    Native.onHome = () => _navigator.currentState?.popUntil((r) => r.isFirst);
  }

  void _applyStatusBar(bool show) {
    if (_statusBarShown == show) return;
    _statusBarShown = show;
    SystemChrome.setEnabledSystemUIMode(
      show ? SystemUiMode.edgeToEdge : SystemUiMode.manual,
      overlays: show ? null : const [SystemUiOverlay.bottom],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Launcher.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        _applyStatusBar(settings.showStatusBar);
        return MaterialApp(
          navigatorKey: _navigator,
          title: 'Launcher',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(
            Brightness.dark,
            black: settings.theme != ThemeChoice.dark,
          ),
          themeMode: switch (settings.theme) {
            ThemeChoice.system => ThemeMode.system,
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark || ThemeChoice.black => ThemeMode.dark,
          },
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value:
                  (dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark)
                      .copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: Colors.transparent,
                      ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
