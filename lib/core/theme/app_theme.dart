import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Mode Switcher ──────────────────────────────────────────
  static bool isDark = true;

  static void setDark() {
    isDark = true;
  }

  static void setLight() {
    isDark = false;
  }

  // ── Absolute ──────────────────────────────────────────
  static const _saffron = Color(0xFFFF9933);
  static const _indiaGreen = Color.fromARGB(255, 10, 123, 0);

  // ── Accents ──────────────────────────────────────────────
  static Color get accent => const Color.fromARGB(255, 10, 123, 0);
  static Color get accentSecondary => _saffron; // used sparsely
  static Color get accentDim => accent.withValues(alpha: 0.20);
  static Color get accentFaint => accent.withValues(alpha: 0.12);

  // ── Backgrounds ──────────────────────────────────────────
  static Color get background =>
      isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color get surface =>
      isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
  static Color get surfaceHigh =>
      isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB);
  static Color get surfaceHighlight =>
      isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB);

  // ── Text ─────────────────────────────────────────────────
  static Color get textPrimary =>
      isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);

  // ── Utility ──────────────────────────────────────────────
  static const error = Color(0xFFF87171);
  static const success = _indiaGreen;
  static Color get divider => textSecondary.withValues(alpha: 0.15);

  // ── Gradients ────────────────────────────────────────────
  static Gradient get subtleCardGradient => LinearGradient(
    colors: [surface.withValues(alpha: 0.8), background],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract class AppTheme {
  static const double pagePadding = 24.0;
  static const double cardPadding = 16.0;

  static ThemeData build() {
    final base = AppColors.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme:
          (AppColors.isDark
                  ? const ColorScheme.dark()
                  : const ColorScheme.light())
              .copyWith(
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
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        backgroundColor: AppColors.background,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
      ),
    );
  }
}
