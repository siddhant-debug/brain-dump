import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm Midnight — Direction 1
/// A warm, cerebral dark theme designed for all users.
/// Single source of truth for every color in the app.
abstract class AppColors {
  // ── Backgrounds ──────────────────────────────────────────
  static const background = Color(0xFF000000); // True OLED Black
  static const surface = Color(0xFF121212);    // Standard Dark Surface
  static const surfaceHigh = Color(0xFF1E1E1E); // Elevated Surface

  // ── Accent ───────────────────────────────────────────────
  static const accent = Color.fromARGB(112, 1, 141, 94);     // Neon Emerald Green
  static Color get accentDim => accent.withValues(alpha: 0.20);
  static Color get accentFaint => accent.withValues(alpha: 0.12);

  // ── Text ─────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF); // Pure White
  static const textSecondary = Color(0xFFA1A1AA); // Zinc Gray

  // ── Utility ──────────────────────────────────────────────
  static const error = Color(0xFFF87171);       // Soft Red
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
