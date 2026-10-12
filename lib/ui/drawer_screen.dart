import 'package:flutter/material.dart';

import '../apps.dart';
import '../native.dart';
import '../scope.dart';
import '../settings.dart';
import 'app_actions.dart';
import 'app_label.dart';

/// All apps, alphabetical, with instant search. Pull down at the top to close.
class DrawerScreen extends StatefulWidget {
  const DrawerScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => const DrawerScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<DrawerScreen> createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<AppEntry> _results() {
    final apps = Launcher.of(context).apps;
    return searchApps(apps.visible, _query.text, apps.labelOf);
  }

  void _onQueryChanged() {
    setState(() {});
    final settings = Launcher.of(context).settings;
    if (!settings.autoLaunch || _query.text.trim().isEmpty) return;
    final results = _results();
    if (results.length == 1) _launch(results.single);
  }

  Future<void> _launch(AppEntry app) async {
    if (_leaving) return;
    _leaving = true;
    final ok = await launchApp(context, app);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      _leaving = false;
    }
  }

  void _onSubmitted(String query) {
    final results = _results();
    if (results.isNotEmpty) {
      _launch(results.first);
    } else if (query.trim().isNotEmpty) {
      Native.open('webSearch', query: query.trim());
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _focus.unfocus();
    }
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        n.metrics.pixels < -80 &&
        !_leaving) {
      _leaving = true;
      Navigator.of(context).pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scope = Launcher.of(context);
    final settings = scope.settings;
    final apps = scope.apps;
    final color = Theme.of(context).colorScheme.onSurface;
    final textAlign = switch (settings.align) {
      HomeAlign.start => TextAlign.start,
      HomeAlign.center => TextAlign.center,
      HomeAlign.end => TextAlign.end,
    };

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: apps,
          builder: (context, _) {
            final results = _results();
            final query = _query.text.trim();
            final offerWebSearch = results.isEmpty && query.isNotEmpty;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    autofocus: settings.drawerKeyboard,
                    autocorrect: false,
                    enableSuggestions: false,
                    textAlign: textAlign,
                    textInputAction: TextInputAction.go,
                    onSubmitted: _onSubmitted,
                    cursorWidth: 1.5,
                    style: TextStyle(
                      fontSize: 22 * settings.textScale,
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: color.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                      itemCount: offerWebSearch ? 1 : results.length,
                      itemBuilder: (context, i) {
                        if (offerWebSearch) {
                          return AppLabel(
                            label: 'Search the web for "$query"',
                            fontSize: 18 * settings.textScale,
                            textAlign: textAlign,
                            expand: true,
                            onTap: () => Native.open('webSearch', query: query),
                          );
                        }
                        final app = results[i];
                        return AppLabel(
                          label: apps.labelOf(app),
                          badge: app.work ? 'work' : null,
                          fontSize: 22 * settings.textScale,
                          textAlign: textAlign,
                          expand: true,
                          onTap: () => _launch(app),
                          onLongPress: () {
                            _focus.unfocus();
                            showAppActions(context, app);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
