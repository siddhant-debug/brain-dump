import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum CircadianPhase { dawn, day, dusk, night }

class CircadianColors {
  final Color bgTop;
  final Color bgBottom;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color accent;
  final Color accentBg;
  final Color accentBorder;
  final Color green;
  final Color greenBg;
  final Color red;
  final Color redBg;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceBorder;
  final Color rHigh;
  final Color rMid;
  final Color rLow;
  final Color spine;
  final Color music;
  final Color location;

  const CircadianColors({
    required this.bgTop,
    required this.bgBottom,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentBg,
    required this.accentBorder,
    required this.green,
    required this.greenBg,
    required this.red,
    required this.redBg,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceBorder,
    required this.rHigh,
    required this.rMid,
    required this.rLow,
    required this.spine,
    required this.music,
    required this.location,
  });

  factory CircadianColors.forPhase(CircadianPhase p) {
    const musicColor = Color(0xFFA78BFA);
    const locationColor = Color(0xFF60A5FA);

    switch (p) {
      case CircadianPhase.dawn:
        return const CircadianColors(
          bgTop: Color(0xFFF5EFE2),
          bgBottom: Color(0xFFEAE0CB),
          accent: Color(0xFFC49A2A),
          accentBg: Color(0x1AC49A2A),
          accentBorder: Color(0x33C49A2A),
          text: Color(0xFF1C1C2E),
          textDim: Color(0xFF6A6A82),
          textFaint: Color(0xFFACACBC),
          green: Color(0xFF4A7C59),
          greenBg: Color(0x1A4A7C59),
          red: Color(0xFFB5341E),
          redBg: Color(0x14B5341E),
          surface: Color(0x99F5EFE2),
          surfaceLow: Color(0x66F5EFE2),
          surfaceBorder: Color(0x121C1C2E),
          rHigh: Color(0xFF52B788),
          rMid: Color(0xFFF5A623),
          rLow: Color(0xFFFF6B6B),
          spine: Color(0x66C49A2A),
          music: musicColor,
          location: locationColor,
        );
      case CircadianPhase.day:
        return const CircadianColors(
          bgTop: Color(0xFFFAFAF8),
          bgBottom: Color(0xFFF0EFEC),
          accent: Color(0xFF2D6A4F),
          accentBg: Color(0x142D6A4F),
          accentBorder: Color(0x2E2D6A4F),
          text: Color(0xFF111111),
          textDim: Color(0xFF606060),
          textFaint: Color(0xFFAAAAAA),
          green: Color(0xFF2D6A4F),
          greenBg: Color(0x142D6A4F),
          red: Color(0xFFC0392B),
          redBg: Color(0x12C0392B),
          surface: Color(0xB8F5F5F2),
          surfaceLow: Color(0x80F5F5F2),
          surfaceBorder: Color(0x12111111),
          rHigh: Color(0xFF52B788),
          rMid: Color(0xFFF5A623),
          rLow: Color(0xFFFF6B6B),
          spine: Color(0x592D6A4F),
          music: musicColor,
          location: locationColor,
        );
      case CircadianPhase.dusk:
        return const CircadianColors(
          bgTop: Color(0xFF1A1728),
          bgBottom: Color(0xFF130F1E),
          accent: Color(0xFFC97C3A),
          accentBg: Color(0x1AC97C3A),
          accentBorder: Color(0x33C97C3A),
          text: Color(0xFFDDD8EC),
          textDim: Color(0xFF9990AA),
          textFaint: Color(0xFF5E5870),
          green: Color(0xFF6BCB77),
          greenBg: Color(0x1A6BCB77),
          red: Color(0xFFFF5A5A),
          redBg: Color(0x1AFF5A5A),
          surface: Color(0x99262238),
          surfaceLow: Color(0x66262238),
          surfaceBorder: Color(0x12DDD8EC),
          rHigh: Color(0xFF52B788),
          rMid: Color(0xFFF5A623),
          rLow: Color(0xFFFF6B6B),
          spine: Color(0x4DC97C3A),
          music: musicColor,
          location: locationColor,
        );
      case CircadianPhase.night:
        return const CircadianColors(
          bgTop: Color(0xFF0C0C0F),
          bgBottom: Color(0xFF070709),
          accent: Color(0xFF8B80E0),
          accentBg: Color(0x1A8B80E0),
          accentBorder: Color(0x338B80E0),
          text: Color(0xFFC4C4CC),
          textDim: Color(0xFF80808A),
          textFaint: Color(0xFF404048),
          green: Color(0xFF4ECDC4),
          greenBg: Color(0x144ECDC4),
          red: Color(0xFFFF6B6B),
          redBg: Color(0x14FF6B6B),
          surface: Color(0xA6121216),
          surfaceLow: Color(0x73121216),
          surfaceBorder: Color(0xFF0F9C9C),
          rHigh: Color(0xFF52B788),
          rMid: Color(0xFFF5A623),
          rLow: Color(0xFFFF6B6B),
          spine: Color(0x4D8B80E0),
          music: musicColor,
          location: locationColor,
        );
    }
  }

  static Color _lc(Color? a, Color? b, double t) =>
      Color.lerp(a, b, t) ?? (b ?? a ?? const Color(0x00000000));

  static CircadianColors lerp(CircadianColors a, CircadianColors b, double t) =>
      CircadianColors(
        bgTop: _lc(a.bgTop, b.bgTop, t),
        bgBottom: _lc(a.bgBottom, b.bgBottom, t),
        text: _lc(a.text, b.text, t),
        textDim: _lc(a.textDim, b.textDim, t),
        textFaint: _lc(a.textFaint, b.textFaint, t),
        accent: _lc(a.accent, b.accent, t),
        accentBg: _lc(a.accentBg, b.accentBg, t),
        accentBorder: _lc(a.accentBorder, b.accentBorder, t),
        green: _lc(a.green, b.green, t),
        greenBg: _lc(a.greenBg, b.greenBg, t),
        red: _lc(a.red, b.red, t),
        redBg: _lc(a.redBg, b.redBg, t),
        surface: _lc(a.surface, b.surface, t),
        surfaceLow: _lc(a.surfaceLow, b.surfaceLow, t),
        surfaceBorder: _lc(a.surfaceBorder, b.surfaceBorder, t),
        rHigh: _lc(a.rHigh, b.rHigh, t),
        rMid: _lc(a.rMid, b.rMid, t),
        rLow: _lc(a.rLow, b.rLow, t),
        spine: _lc(a.spine, b.spine, t),
        music: _lc(a.music, b.music, t),
        location: _lc(a.location, b.location, t),
      );

  // Fallback map for easy color access if needed, but forPhase is preferred
  static CircadianColors get current => CircadianColors.forPhase(CircadianPhase.night);
}

class AppTextStyles {
  static TextStyle h1(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -1,
  );

  static TextStyle h2(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  static TextStyle h3(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle greeting(Color c) => GoogleFonts.crimsonPro(
    color: c,
    fontSize: 26,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.01,
  );

  static TextStyle serifBody(Color c) => GoogleFonts.crimsonPro(
    color: c,
    fontSize: 14,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
  );

  static TextStyle label(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.09,
  );

  static TextStyle body(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 12,
    fontWeight: FontWeight.w300,
  );

  static TextStyle bodyMed(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle caption(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );

  static TextStyle micro(Color c) => GoogleFonts.dmSans(
    color: c,
    fontSize: 9,
    fontWeight: FontWeight.w400,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 26;
}

class AppRadius {
  static const double pill = 20;
  static const double card = 14;
  static const double input = 16;
  static const double icon = 6;
  static const double large = 24;
}

class AppDuration {
  static const skeletonCycle = Duration(milliseconds: 1200);
  static const phaseCheck = Duration(minutes: 1);
  static const sendingFade = Duration(milliseconds: 300);
  static const phaseTransition = Duration(milliseconds: 600);
}

abstract class AppTheme {
  static const double pagePadding = AppSpacing.xl;
  static const double cardPadding = AppSpacing.md;

  static ThemeData build(CircadianPhase phase) {
    final colors = CircadianColors.forPhase(phase);
    final isDark = phase == CircadianPhase.dusk || phase == CircadianPhase.night;
    
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: colors.bgTop,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: colors.bgTop,
        primary: colors.accent,
        secondary: colors.textDim,
        error: colors.red,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: colors.text,
        displayColor: colors.text,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accentBg,
        selectionHandleColor: colors.accent,
      ),
      dividerTheme: DividerThemeData(
        color: colors.surfaceBorder,
        thickness: 0.5,
      ),
    );
  }
}

/// Compatibility Shim for legacy code.
/// This will be retired as Stage 2 progresses.
class AppColors {
  static CircadianPhase get _p {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return CircadianPhase.dawn;
    if (hour >= 10 && hour < 17) return CircadianPhase.day;
    if (hour >= 17 && hour < 21) return CircadianPhase.dusk;
    return CircadianPhase.night;
  }
  static CircadianColors get _c => CircadianColors.forPhase(_p);

  static bool isDark = true;
  static void setDark() { isDark = true; }
  static void setLight() { isDark = false; }

  static Color get accent => _c.accent;
  static Color get accentFaint => _c.accentBg;
  static Color get textPrimary => _c.text;
  static Color get textSecondary => _c.textDim;
  static Color get background => _c.bgTop;
  static Color get surface => _c.surface;
  static Color get surfaceLow => _c.surfaceLow;
  static Color get surfaceHigh => _c.surface;
  static Color get surfaceHighlight => _c.surface;
  static Color get error => _c.red;
  static Color get success => _c.green;
  static Color get divider => _c.surfaceBorder;
  static Gradient get subtleCardGradient => LinearGradient(
    colors: [_c.surface, _c.bgTop],
  );
}

