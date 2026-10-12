import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeChoice { system, light, dark, black }

enum HomeAlign { start, center, end }

enum Gesture { swipeLeft, swipeRight, swipeDown, doubleTap }

/// Everything the user can change, persisted on every write.
class Settings extends ChangeNotifier {
  Settings._(this._prefs)
    : _favorites = _prefs.getStringList('favorites') ?? [],
      _hidden = (_prefs.getStringList('hidden') ?? []).toSet(),
      _renames = _decodeMap(_prefs.getString('renames')),
      _gestures = _decodeMap(_prefs.getString('gestures'));

  static Future<Settings> load() async => Settings._(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    ),
  );

  final SharedPreferencesWithCache _prefs;

  static const maxFavorites = 8;

  static const defaultGestures = {
    Gesture.swipeLeft: 'phone',
    Gesture.swipeRight: 'camera',
    Gesture.swipeDown: 'notifications',
    Gesture.doubleTap: 'lock',
  };

  // Home apps

  final List<String> _favorites;
  List<String> get favorites => List.unmodifiable(_favorites);
  bool isFavorite(String key) => _favorites.contains(key);
  bool get favoritesFull => _favorites.length >= maxFavorites;

  void addFavorite(String key) {
    if (isFavorite(key) || favoritesFull) return;
    _favorites.add(key);
    _saveFavorites();
  }

  void removeFavorite(String key) {
    if (_favorites.remove(key)) _saveFavorites();
  }

  void moveFavorite(int from, int to) {
    final key = _favorites.removeAt(from);
    _favorites.insert(to.clamp(0, _favorites.length), key);
    _saveFavorites();
  }

  void _saveFavorites() {
    _prefs.setStringList('favorites', _favorites);
    notifyListeners();
  }

  // Hidden apps

  final Set<String> _hidden;
  Set<String> get hidden => _hidden;

  void setHidden(String key, bool hide) {
    final changed = hide ? _hidden.add(key) : _hidden.remove(key);
    if (!changed) return;
    _prefs.setStringList('hidden', _hidden.toList());
    notifyListeners();
  }

  // Renamed apps

  final Map<String, String> _renames;
  Map<String, String> get renames => _renames;

  /// An empty [name] restores the app's own label.
  void rename(String key, String name) {
    name = name.trim();
    if (name.isEmpty) {
      _renames.remove(key);
    } else {
      _renames[key] = name;
    }
    _prefs.setString('renames', jsonEncode(_renames));
    notifyListeners();
  }

  // Gestures

  final Map<String, String> _gestures;

  /// A built-in action name (see gestures.dart) or `app:<key>`.
  String gesture(Gesture g) => _gestures[g.name] ?? defaultGestures[g]!;

  void setGesture(Gesture g, String action) {
    _gestures[g.name] = action;
    _prefs.setString('gestures', jsonEncode(_gestures));
    notifyListeners();
  }

  // Appearance and behavior

  ThemeChoice get theme =>
      _enum(ThemeChoice.values, 'theme') ?? ThemeChoice.black;
  set theme(ThemeChoice v) => _set('theme', v.name);

  HomeAlign get align => _enum(HomeAlign.values, 'align') ?? HomeAlign.start;
  set align(HomeAlign v) => _set('align', v.name);

  double get textScale => _prefs.getDouble('textScale') ?? 1.0;
  set textScale(double v) => _set('textScale', v);

  bool get showClock => _prefs.getBool('showClock') ?? true;
  set showClock(bool v) => _set('showClock', v);

  bool get showDate => _prefs.getBool('showDate') ?? true;
  set showDate(bool v) => _set('showDate', v);

  bool get showStatusBar => _prefs.getBool('showStatusBar') ?? true;
  set showStatusBar(bool v) => _set('showStatusBar', v);

  /// Open the app as soon as a search leaves exactly one match.
  bool get autoLaunch => _prefs.getBool('autoLaunch') ?? true;
  set autoLaunch(bool v) => _set('autoLaunch', v);

  bool get drawerKeyboard => _prefs.getBool('drawerKeyboard') ?? true;
  set drawerKeyboard(bool v) => _set('drawerKeyboard', v);

  T? _enum<T extends Enum>(List<T> values, String key) {
    final name = _prefs.getString(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  void _set(String key, Object value) {
    switch (value) {
      case bool v:
        _prefs.setBool(key, v);
      case double v:
        _prefs.setDouble(key, v);
      case String v:
        _prefs.setString(key, v);
    }
    notifyListeners();
  }

  static Map<String, String> _decodeMap(String? json) {
    if (json == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(json) as Map);
    } catch (_) {
      return {};
    }
  }
}
