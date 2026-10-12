import 'package:flutter/material.dart';

/// Monochrome themes. The black theme is the default: on OLED screens black
/// pixels are switched off, which is where most of the battery saving comes from.
ThemeData buildTheme(Brightness brightness, {bool black = false}) {
  final dark = brightness == Brightness.dark;
  final bg = dark
      ? (black ? Colors.black : const Color(0xFF161616))
      : const Color(0xFFF6F5F2);
  final fg = dark ? const Color(0xFFECECEC) : const Color(0xFF161616);
  final raised = dark
      ? (black ? const Color(0xFF111111) : const Color(0xFF222222))
      : Colors.white;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF808080),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: fg,
        onPrimary: bg,
        surface: bg,
        onSurface: fg,
        surfaceContainerLowest: raised,
        surfaceContainerLow: raised,
        surfaceContainer: raised,
        surfaceContainerHigh: raised,
        surfaceContainerHighest: raised,
        outlineVariant: fg.withValues(alpha: 0.12),
      );

  final typography = Typography.material2021().englishLike.merge(
    dark ? Typography.material2021().white : Typography.material2021().black,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: typography.titleLarge!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w300,
        color: fg,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: fg,
      selectionColor: fg.withValues(alpha: 0.2),
      selectionHandleColor: fg,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: fg,
      contentTextStyle: TextStyle(color: bg),
    ),
  );
}
