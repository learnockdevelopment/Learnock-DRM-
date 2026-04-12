import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _kDarkModeKey = 'theme_is_dark';

  bool _isDarkMode = true;
  String? _currentTheme;
  String? _currentThemeColor;

  bool get isDarkMode => _isDarkMode;
  String? get currentTheme => _currentTheme;
  String? get currentThemeColor => _currentThemeColor;

  ThemeData get themeData => _generateThemeData(_isDarkMode, _currentTheme, _currentThemeColor);
  ThemeData get lightThemeData => _generateThemeData(false, _currentTheme, _currentThemeColor);
  ThemeData get darkThemeData => _generateThemeData(true, _currentTheme, _currentThemeColor);

  // Restore saved preference; fall back to system brightness
  Future<void> init() async {
    try {
      final saved = await _storage.read(key: _kDarkModeKey);
      if (saved != null) {
        _isDarkMode = saved == 'true';
      } else {
        // No saved preference — follow system dark/light setting
        _isDarkMode = SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      }
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _storage.write(key: _kDarkModeKey, value: _isDarkMode.toString());
    notifyListeners();
  }

  void setTenant(String? themeName, {String? themeColor}) {
    if (_currentTheme != themeName || _currentThemeColor != themeColor) {
      _currentTheme = themeName;
      _currentThemeColor = themeColor;
      notifyListeners();
    }
  }

  static Color fromHSL(double h, double s, double l) {
    return HSLColor.fromAHSL(1.0, h, s / 100, l / 100).toColor();
  }

  static Color hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.transparent;
    try {
      final buffer = StringBuffer();
      String clean = hex.replaceFirst('#', '');
      if (clean.length == 6) buffer.write('ff');
      buffer.write(clean);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  ThemeData _generateThemeData(bool isDark, String? themeName, String? themeColorHex) {
    final t = themeName?.toLowerCase() ?? 'default';

    // DEFAULT (EMERALD) - Base SaaS Palette
    Color primary = isDark ? fromHSL(160, 50, 65) : fromHSL(160, 85, 40);

    // OVERRIDE WITH THEME COLOR FROM API IF VALID
    if (themeColorHex != null && themeColorHex.contains('#')) {
      final String pureHex = themeColorHex.split('#').last;
      if (pureHex.length == 6) {
        primary = Color(int.parse("0xff$pureHex"));
      }
    } else {
      // DYNAMIC BRAND MAPPINGS
      if (t == 'midnight' || t == 'slate' || t == 'dark') {
        primary = isDark ? fromHSL(230, 85, 60) : fromHSL(225, 80, 55);
      } else if (t == 'forest' || t == 'green') {
        primary = isDark ? fromHSL(150, 60, 50) : fromHSL(150, 60, 35);
      } else if (t == 'sunset' || t == 'orange' || t == 'amber') {
        primary = isDark ? fromHSL(15, 85, 60) : fromHSL(15, 80, 55);
      } else if (t == 'royal' || t == 'purple' || t == 'violet') {
        primary = isDark ? fromHSL(270, 80, 60) : fromHSL(270, 70, 45);
      } else if (t == 'ocean' || t == 'blue' || t == 'sky') {
        primary = isDark ? fromHSL(195, 90, 55) : fromHSL(195, 85, 45);
      } else if (t == 'lavender' || t == 'pink' || t == 'rose') {
        primary = isDark ? fromHSL(265, 80, 70) : fromHSL(265, 70, 60);
      } else if (t == 'ember' || t == 'red') {
        primary = isDark ? fromHSL(10, 90, 60) : fromHSL(10, 80, 55);
      }
    }

    Color scaffoldBg = isDark ? fromHSL(222, 47, 4) : fromHSL(210, 40, 98);
    Color cardColor = isDark ? fromHSL(222, 47, 7) : Colors.white;
    Color divider = isDark ? fromHSL(222, 47, 12) : fromHSL(214, 32, 91);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      dividerColor: divider,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              surface: cardColor,
              onSurface: Colors.white,
              onSurfaceVariant: Colors.white.withOpacity(0.6),
            )
          : ColorScheme.light(
              primary: primary,
              surface: cardColor,
              onSurface: const Color(0xFF0F172A),
              onSurfaceVariant: const Color(0xFF64748B),
            ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w900),
        titleLarge: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      ),
    );
  }
}
