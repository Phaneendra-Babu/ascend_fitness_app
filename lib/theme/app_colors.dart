import 'package:flutter/material.dart';

/// Extension on BuildContext to provide easy access to theme-aware colors.
/// Colors are driven by the current mode (survival/hunter/beast) + brightness.
/// Usage: `context.accent`, `context.cardColor`, `context.textPrimary`, etc.
extension AppColors on BuildContext {
  ColorScheme get _scheme => Theme.of(this).colorScheme;
  Brightness get _brightness => Theme.of(this).brightness;
  bool get isDark => _brightness == Brightness.dark;

  // ── Mode-aware accent (from ColorScheme) ─────────────────────────
  Color get accent => _scheme.primary;
  Color get accentLight => _scheme.secondary;
  Color get accentTertiary => _scheme.tertiary;

  // ── Background ──────────────────────────────────────────────────
  Color get background => Theme.of(this).scaffoldBackgroundColor;

  // ── Cards & Surfaces ────────────────────────────────────────────
  Color get cardColor => _scheme.surface;
  Color get cardColorAlt => isDark
      ? _scheme.surface.withValues(alpha: 1.2)
      : _scheme.surface;
  Color get surfaceVariant => isDark
      ? _scheme.surface.withValues(alpha: 1.3)
      : _scheme.surface;
  Color get inputFill => _scheme.surface;

  // ── Text ────────────────────────────────────────────────────────
  Color get textPrimary => _scheme.onSurface;
  Color get textSecondary => _scheme.onSurface.withValues(alpha: 0.6);
  Color get textMuted => _scheme.onSurface.withValues(alpha: 0.4);

  // ── Borders & Dividers ──────────────────────────────────────────
  Color get border => isDark
      ? _scheme.primary.withValues(alpha: 0.12)
      : _scheme.outline.withValues(alpha: 0.3);
  Color get divider => _scheme.outline.withValues(alpha: isDark ? 0.15 : 0.1);
  Color get borderLight => _scheme.outline.withValues(alpha: 0.2);

  // ── Shadows ─────────────────────────────────────────────────────
  Color get shadow => isDark
      ? Colors.black.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.04);
  Color get shadowLight => isDark
      ? Colors.black.withValues(alpha: 0.2)
      : Colors.black.withValues(alpha: 0.03);

  // ── Chip / Tag backgrounds ──────────────────────────────────────
  Color get chipBg => isDark
      ? _scheme.primary.withValues(alpha: 0.1)
      : _scheme.primary.withValues(alpha: 0.06);
  Color get chipBorder => isDark
      ? _scheme.primary.withValues(alpha: 0.2)
      : _scheme.primary.withValues(alpha: 0.15);

  // ── Status colors ───────────────────────────────────────────────
  Color get success => const Color(0xFF10B981);
  Color get error => const Color(0xFFEF4444);
  Color get warning => const Color(0xFFF59E0B);
  Color get info => const Color(0xFF38BDF8);

  // ── Nav bar ─────────────────────────────────────────────────────
  Color get navBarBackground => isDark
      ? _scheme.surface.withValues(alpha: 0.95)
      : _scheme.surface;
  Color get navBarShadow => isDark
      ? Colors.black.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.05);

  // ── Progress ────────────────────────────────────────────────────
  Color get progressTrack => isDark
      ? _scheme.primary.withValues(alpha: 0.15)
      : _scheme.primary.withValues(alpha: 0.1);
}
