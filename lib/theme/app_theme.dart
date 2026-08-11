import 'package:flutter/material.dart';
import '../models/xp_system.dart';

class AppTheme {
  AppTheme._();

  // ─── Mode Color Maps ─────────────────────────────────────────────────────
  // survival = blue, hunter = purple, beast = red

  static const _survivalDark = _ModeColors(
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF00CFFF),
    accent: Color(0xFF38BDF8),
    background: Color(0xFF0B1220),
    surface: Color(0xFF111827),
    surfaceAlt: Color(0xFF151C2C),
    cardBorder: Color(0xFF1F2937),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    navBg: Color(0xFF111827),
    inputFill: Color(0xFF1A2332),
    divider: Color(0xFF1F2937),
    chipBg: Color(0xFF1A2332),
    chipBorder: Color(0xFF253043),
    progressTrack: Color(0xFF1F2937),
  );

  static const _survivalLight = _ModeColors(
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF00CFFF),
    accent: Color(0xFF3B82F6),
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF8FAFC),
    cardBorder: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF1E293B),
    textSecondary: Color(0xFF64748B),
    navBg: Colors.white,
    inputFill: Colors.white,
    divider: Color(0xFFF1F5F9),
    chipBg: Colors.white,
    chipBorder: Color(0xFFE2E8F0),
    progressTrack: Color(0xFFE2E8F0),
  );

  static const _hunterDark = _ModeColors(
    primary: Color(0xFF7C3AED),
    secondary: Color(0xFFA78BFA),
    accent: Color(0xFF9333EA),
    background: Color(0xFF050508),
    surface: Color(0xFF0D0D14),
    surfaceAlt: Color(0xFF0A0A10),
    cardBorder: Color(0xFF1A1525),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFB8B0C8),
    navBg: Color(0xFF0D0D14),
    inputFill: Color(0xFF0F0F18),
    divider: Color(0xFF1A1525),
    chipBg: Color(0xFF0F0F18),
    chipBorder: Color(0xFF1A1525),
    progressTrack: Color(0xFF0F0F18),
  );

  static const _hunterLight = _ModeColors(
    primary: Color(0xFF7C3AED),
    secondary: Color(0xFFA78BFA),
    accent: Color(0xFF8B5CF6),
    background: Color(0xFFF8F5FF),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF8F5FF),
    cardBorder: Color(0xFFE9D8FD),
    textPrimary: Color(0xFF1E1B2E),
    textSecondary: Color(0xFF6B7280),
    navBg: Colors.white,
    inputFill: Colors.white,
    divider: Color(0xFFEDE9FE),
    chipBg: Color(0xFFEDE9FE),
    chipBorder: Color(0xFFE9D8FD),
    progressTrack: Color(0xFFE9D5FF),
  );

  static const _beastDark = _ModeColors(
    primary: Color(0xFFDC2626),
    secondary: Color(0xFFF87171),
    accent: Color(0xFFEF4444),
    background: Color(0xFF050505),
    surface: Color(0xFF0D0D0D),
    surfaceAlt: Color(0xFF0A0A0A),
    cardBorder: Color(0xFF1A1212),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFB0A0A0),
    navBg: Color(0xFF0D0D0D),
    inputFill: Color(0xFF0F0F0F),
    divider: Color(0xFF1A1212),
    chipBg: Color(0xFF0F0F0F),
    chipBorder: Color(0xFF1A1212),
    progressTrack: Color(0xFF0F0F0F),
  );

  static const _beastLight = _ModeColors(
    primary: Color(0xFFDC2626),
    secondary: Color(0xFFF87171),
    accent: Color(0xFFB91C1C),
    background: Color(0xFFFFF8F8),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFFF8F8),
    cardBorder: Color(0xFFFECACA),
    textPrimary: Color(0xFF1C0A0A),
    textSecondary: Color(0xFF6B7280),
    navBg: Colors.white,
    inputFill: Colors.white,
    divider: Color(0xFFFEE2E2),
    chipBg: Color(0xFFFEE2E2),
    chipBorder: Color(0xFFFECACA),
    progressTrack: Color(0xFFFEE2E2),
  );

  static _ModeColors _getColors(AppMode mode, bool isDark) {
    switch (mode) {
      case AppMode.survival:
        return isDark ? _survivalDark : _survivalLight;
      case AppMode.hunter:
        return isDark ? _hunterDark : _hunterLight;
      case AppMode.beast:
        return isDark ? _beastDark : _beastLight;
    }
  }

  /// Generate a complete ThemeData for the given mode and brightness.
  static ThemeData getTheme(AppMode mode, bool isDark) {
    final c = _getColors(mode, isDark);
    final brightness = isDark ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: Colors.white,
      secondary: c.secondary,
      onSecondary: Colors.white,
      tertiary: c.accent,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      primaryColor: c.primary,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: isDark ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? c.primary.withValues(alpha: 0.12)
                : c.cardBorder,
          ),
        ),
      ),
      textTheme: TextTheme(
        displayMedium: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.bold,
          color: c.textPrimary,
        ),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: c.textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: c.textSecondary),
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navBg.withValues(alpha: isDark ? 0.95 : 1.0),
        indicatorColor: c.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.primary);
          }
          return IconThemeData(color: c.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: c.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return TextStyle(color: c.textSecondary, fontSize: 12);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.primary,
      ),
      dividerColor: c.divider,
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: c.textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        modalBackgroundColor: c.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : c.textPrimary,
        contentTextStyle: TextStyle(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        hintStyle: TextStyle(color: c.textSecondary),
        labelStyle: TextStyle(color: c.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        iconColor: c.textSecondary,
        prefixIconColor: c.textSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.chipBg,
        selectedColor: c.primary,
        disabledColor: c.chipBg,
        labelStyle: TextStyle(color: c.textSecondary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.chipBorder),
        ),
        side: BorderSide(color: c.chipBorder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.textPrimary,
        iconColor: c.textSecondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary.withValues(alpha: 0.4);
          }
          return isDark ? Colors.grey.shade800 : Colors.grey.shade300;
        }),
      ),
    );
  }
}

/// Internal value class to hold per-mode color sets.
class _ModeColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color navBg;
  final Color inputFill;
  final Color divider;
  final Color chipBg;
  final Color chipBorder;
  final Color progressTrack;

  const _ModeColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.navBg,
    required this.inputFill,
    required this.divider,
    required this.chipBg,
    required this.chipBorder,
    required this.progressTrack,
  });
}
