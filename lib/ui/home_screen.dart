import 'package:flutter/material.dart';

import '../scope.dart';
import '../settings.dart';
import 'app_actions.dart';
import 'app_label.dart';
import 'clock.dart';
import 'drawer_screen.dart';
import 'gestures.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _minDistance = 60.0;
  static const _minVelocity = 600.0;

  double _dx = 0, _dy = 0;

  bool _isSwipe(double distance, double velocity, {required bool forward}) =>
      forward
      ? distance > _minDistance || velocity > _minVelocity
      : distance < -_minDistance || velocity < -_minVelocity;

  void _onVerticalEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_isSwipe(_dy, v, forward: false)) {
      Navigator.of(context).push(DrawerScreen.route());
    } else if (_isSwipe(_dy, v, forward: true)) {
      runGesture(context, Gesture.swipeDown);
    }
  }

  void _onHorizontalEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_isSwipe(_dx, v, forward: false)) {
      runGesture(context, Gesture.swipeLeft);
    } else if (_isSwipe(_dx, v, forward: true)) {
      runGesture(context, Gesture.swipeRight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = Launcher.of(context);
    final settings = scope.settings;
    final apps = scope.apps;
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.45);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: apps,
          builder: (context, _) {
            final cross = switch (settings.align) {
              HomeAlign.start => CrossAxisAlignment.start,
              HomeAlign.center => CrossAxisAlignment.center,
              HomeAlign.end => CrossAxisAlignment.end,
            };
            final textAlign = switch (settings.align) {
              HomeAlign.start => TextAlign.start,
              HomeAlign.center => TextAlign.center,
              HomeAlign.end => TextAlign.end,
            };
            final x = switch (settings.align) {
              HomeAlign.start => -1.0,
              HomeAlign.center => 0.0,
              HomeAlign.end => 1.0,
            };
            final favorites = apps.favorites;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _dy = 0,
              onVerticalDragUpdate: (d) => _dy += d.delta.dy,
              onVerticalDragEnd: _onVerticalEnd,
              onHorizontalDragStart: (_) => _dx = 0,
              onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
              onHorizontalDragEnd: _onHorizontalEnd,
              child: Stack(
                children: [
                  // Empty space only, so double tap never delays opening an app.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: () => runGesture(context, Gesture.doubleTap),
                      onLongPress: () => openSettings(context),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 56, 32, 56),
                      child: Column(
                        crossAxisAlignment: cross,
                        children: [
                          if (settings.showClock || settings.showDate)
                            Clock(
                              showTime: settings.showClock,
                              showDate: settings.showDate,
                              crossAxisAlignment: cross,
                              scale: settings.textScale,
                            ),
                          // Favorites sit low, within thumb reach, and shrink
                          // rather than overflow on small screens.
                          Expanded(
                            child: Align(
                              alignment: Alignment(x, 1),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment(x, 1),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: cross,
                                  children: [
                                    if (apps.loaded && favorites.isEmpty)
                                      GestureDetector(
                                        onTap: () => openSettings(context),
                                        child: Text(
                                          'Swipe up for all apps.\n'
                                          'Long-press an app to add it here.',
                                          textAlign: textAlign,
                                          style: TextStyle(
                                            fontSize: 16,
                                            height: 1.6,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                    for (final app in favorites)
                                      AppLabel(
                                        label: apps.labelOf(app),
                                        fontSize: 26 * settings.textScale,
                                        textAlign: textAlign,
                                        onTap: () => launchApp(context, app),
                                        onLongPress: () =>
                                            showAppActions(context, app),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
