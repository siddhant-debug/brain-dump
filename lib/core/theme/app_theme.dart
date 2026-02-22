import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm Midnight — Direction 1
/// A warm, cerebral dark theme designed for all users.
/// Single source of truth for every color in the app.
abstract class AppColors {
  // ── Backgrounds ──────────────────────────────────────────
  /// Main scaffold background — warm deep charcoal (#13111A)
  static const background = Color(0xFF13111A);

  /// Cards, dock, sheets, dialogs (#1E1B2E)
  static const surface = Color(0xFF1E1B2E);

  /// Elevated surfaces, input borders (#2A2740)
  static const surfaceHigh = Color(0xFF2A2740);

  // ── Accent ───────────────────────────────────────────────
  /// Soft lavender-violet — AI elements, active states (#C084FC)
  static const accent = Color(0xFFC084FC);

  /// Accent at 20% — subtle glows, inactive borders
  static Color get accentDim => accent.withValues(alpha: 0.20);

  /// Accent at 12% — very subtle backgrounds on AI avatars
  static Color get accentFaint => accent.withValues(alpha: 0.12);

  // ── Text ─────────────────────────────────────────────────
  /// Primary text — warm off-white (#F4F0FF)
  static const textPrimary = Color(0xFFF4F0FF);

  /// Secondary text — muted lilac-grey (#8B83A3)
  static const textSecondary = Color(0xFF8B83A3);

  // ── Utility ──────────────────────────────────────────────
  /// Error / destructive (#F87171)
  static const error = Color(0xFFF87171);

  /// Dividers, subtle separators
  static Color get divider => textSecondary.withValues(alpha: 0.15);
}

abstract class AppTheme {
  // Global layout constants
  static const double pagePadding = 24.0;
  static const double cardPadding = 16.0;

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.textSecondary,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accentDim,
        selectionHandleColor: AppColors.accent,
      ),
      // Dialogs
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      // Snackbars
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
      // Progress indicators default to accent
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }
}
