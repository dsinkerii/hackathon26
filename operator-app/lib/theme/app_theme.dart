import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Цветовая тема приложения (акцентный цвет iOS-палитры).
class PlayTheme {
  const PlayTheme(this.id, this.label, this.accent);

  final String id;
  final String label;
  final Color accent;

  /// Светлый оттенок темы для «подушек» индикаторов и плашек.
  Color get soft => Color.lerp(accent, Colors.white, 0.84)!;
}

class AppThemes {
  const AppThemes._();

  /// Тема по умолчанию — приложение всегда стартует с неё при отсутствии
  /// сохранённого выбора.
  static const PlayTheme blue = PlayTheme('blue', 'Синяя', Color(0xFF007AFF));

  static final List<PlayTheme> all = <PlayTheme>[
    blue,
    const PlayTheme('teal', 'Бирюзовая', Color(0xFF30B0C7)),
    const PlayTheme('green', 'Зелёная', Color(0xFF34C759)),
    const PlayTheme('orange', 'Оранжевая', Color(0xFFFF9500)),
    const PlayTheme('indigo', 'Сиреневая', Color(0xFF5856D6)),
    const PlayTheme('pink', 'Розовая', Color(0xFFFF2D55)),
  ];

  static PlayTheme byId(String? id) {
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return blue;
  }
}

/// Светлый оттенок произвольного акцента — для «подушек» индикаторов
/// и плашек, построенных на scheme.primary.
Color accentSoftOf(Color accent) => Color.lerp(accent, Colors.white, 0.84)!;

/// Глобальный контроллер активной темы: выбор сохраняется в
/// SharedPreferences и переживает перезагрузку страницы.
class ThemeController {
  ThemeController._();

  static const _storageKey = 'safe_playground_theme';

  static final ValueNotifier<PlayTheme> active = ValueNotifier(AppThemes.blue);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      active.value = AppThemes.byId(prefs.getString(_storageKey));
    } catch (_) {
      // Плагин недоступен (например, в тестах) — остаёмся на теме по
      // умолчанию.
    }
  }

  static Future<void> select(PlayTheme theme) async {
    active.value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, theme.id);
    } catch (_) {
      // Не удалось сохранить — тема всё равно применена в сеансе.
    }
  }
}

ThemeData buildPlaygroundTheme(PlayTheme theme) {
  final accent = theme.accent;
  final accentSoft = theme.soft;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      secondary: const Color(0xFF5856D6),
      onSecondary: Colors.white,
      error: const Color(0xFFFF3B30),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1D1D1F),
      onSurfaceVariant: const Color(0xFF6E6E73),
      outline: const Color(0xFFD2D2D7),
      outlineVariant: const Color(0xFFE5E5EA),
      surfaceContainerHighest: const Color(0xFFF5F5F7),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F7),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F5F7),
      foregroundColor: Color(0xFF1D1D1F),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B30)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(color: Color(0xFFD2D2D7)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFFF5F5F7),
      indicatorColor: accentSoft,
      selectedIconTheme: IconThemeData(color: accent),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF6E6E73)),
      selectedLabelTextStyle: TextStyle(
        color: accent,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xFF6E6E73)),
      minExtendedWidth: 244,
      useIndicator: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: accentSoft,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
