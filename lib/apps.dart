import 'package:flutter/foundation.dart';

import 'native.dart';
import 'settings.dart';

@immutable
class AppEntry {
  const AppEntry({
    required this.label,
    required this.package,
    required this.activity,
    this.user = 0,
    this.work = false,
  });

  factory AppEntry.fromMap(Map<Object?, Object?> m) => AppEntry(
    label: m['label'] as String,
    package: m['package'] as String,
    activity: m['activity'] as String,
    user: (m['user'] as num?)?.toInt() ?? 0,
    work: m['work'] as bool? ?? false,
  );

  final String label;
  final String package;
  final String activity;

  /// Serial number of the Android user profile (work profile apps differ).
  final int user;
  final bool work;

  /// Stable id used to remember favorites, renames and hidden apps.
  String get key => '$package/$activity@$user';

  Map<String, Object?> get args => {
    'package': package,
    'activity': activity,
    'user': user,
  };
}

/// Apps whose label matches [query], best matches first: labels that start
/// with the query, then labels with a word that starts with it, then the rest.
List<AppEntry> searchApps(
  List<AppEntry> apps,
  String query,
  String Function(AppEntry) labelOf,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return apps;
  final prefix = <AppEntry>[], word = <AppEntry>[], other = <AppEntry>[];
  for (final app in apps) {
    final label = labelOf(app).toLowerCase();
    if (label.startsWith(q)) {
      prefix.add(app);
    } else if (label.contains(' $q')) {
      word.add(app);
    } else if (label.contains(q)) {
      other.add(app);
    }
  }
  return [...prefix, ...word, ...other];
}

class AppRepository extends ChangeNotifier {
  AppRepository(this.settings) {
    settings.addListener(_invalidate);
  }

  final Settings settings;

  List<AppEntry> _all = const [];
  List<AppEntry>? _sorted;
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> refresh() async {
    _all = await Native.getApps();
    _loaded = true;
    _invalidate();
  }

  void _invalidate() {
    _sorted = null;
    notifyListeners();
  }

  String labelOf(AppEntry app) => settings.renames[app.key] ?? app.label;

  /// Every app, sorted by the name the user sees.
  List<AppEntry> get all => _sorted ??= [..._all]
    ..sort(
      (a, b) => labelOf(a).toLowerCase().compareTo(labelOf(b).toLowerCase()),
    );

  List<AppEntry> get visible =>
      all.where((a) => !settings.hidden.contains(a.key)).toList();

  List<AppEntry> get hiddenApps =>
      all.where((a) => settings.hidden.contains(a.key)).toList();

  /// Favorites in the user's order. Apps that are uninstalled are skipped but
  /// stay remembered, so reinstalling brings them back.
  List<AppEntry> get favorites {
    final byKey = {for (final a in _all) a.key: a};
    return [for (final k in settings.favorites) ?byKey[k]];
  }

  AppEntry? byKey(String key) {
    for (final a in _all) {
      if (a.key == key) return a;
    }
    return null;
  }

  @override
  void dispose() {
    settings.removeListener(_invalidate);
    super.dispose();
  }
}
