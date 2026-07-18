import 'package:flutter/material.dart';

/// Semantic ThriftyChef palette — clean soft-white / teal / coral design system.
@immutable
class ThriftyChefColors extends ThemeExtension<ThriftyChefColors> {
  final Color background;
  final Color frost;
  final Color glacierDeep;
  final Color glacier;
  final Color glacierMid;
  final Color iceLight;
  final Color iceAccent;
  final Color roseAccent;
  final Color arcticGlow;
  final Color warningOrange;
  final Color dangerRed;
  final Color goodTeal;
  final Color textPrimary;
  final Color textMuted;
  final Color cardBorder;
  final Color cardSurface;
  final List<Color> heroGradient;
  final List<Color> phase2Gradient;
  final bool useGlow;

  const ThriftyChefColors({
    required this.background,
    required this.frost,
    required this.glacierDeep,
    required this.glacier,
    required this.glacierMid,
    required this.iceLight,
    required this.iceAccent,
    required this.roseAccent,
    required this.arcticGlow,
    required this.warningOrange,
    required this.dangerRed,
    required this.goodTeal,
    required this.textPrimary,
    required this.textMuted,
    required this.cardBorder,
    required this.cardSurface,
    required this.heroGradient,
    required this.phase2Gradient,
    required this.useGlow,
  });

  /// Light — soft white (~70%), teal actions (~20%), coral branding (~10%).
  static const light = ThriftyChefColors(
    background: Color(0xFFF8FAFC),
    frost: Color(0xFFFFFFFF),
    glacierDeep: Color(0xFF268387),
    glacier: Color(0xFF34A0A4),
    glacierMid: Color(0xFF4DB4B8),
    iceLight: Color(0xFFEEF7F8),
    iceAccent: Color(0xFFD9F2F3),
    roseAccent: Color(0xFFE5A99E),
    arcticGlow: Color(0xFF4DB4B8),
    warningOrange: Color(0xFFF59E0B),
    dangerRed: Color(0xFFEF4444),
    goodTeal: Color(0xFF22C55E),
    textPrimary: Color(0xFF1E293B),
    textMuted: Color(0xFF64748B),
    cardBorder: Color(0xFFE5E7EB),
    cardSurface: Color(0xFFFFFFFF),
    // Light teal hero (#EAF8F8 → #D9F2F3) — food photos stay the focus
    heroGradient: [Color(0xFFEAF8F8), Color(0xFFD9F2F3)],
    phase2Gradient: [Color(0xFFEAF8F8), Color(0xFFD9F2F3)],
    useGlow: false,
  );

  /// Dark — deep navy with restrained teal accents.
  static const dark = ThriftyChefColors(
    background: Color(0xFF0F172A),
    frost: Color(0xFF1E293B),
    glacierDeep: Color(0xFF268387),
    glacier: Color(0xFF34A0A4),
    glacierMid: Color(0xFF4DB4B8),
    iceLight: Color(0xFF1A3A3C),
    iceAccent: Color(0xFF6EC8CC),
    roseAccent: Color(0xFFE5A99E),
    arcticGlow: Color(0xFF4DB4B8),
    warningOrange: Color(0xFFF59E0B),
    dangerRed: Color(0xFFEF4444),
    goodTeal: Color(0xFF22C55E),
    textPrimary: Color(0xFFF1F5F9),
    textMuted: Color(0xFF94A3B8),
    cardBorder: Color(0xFF334155),
    cardSurface: Color(0xFF1E293B),
    heroGradient: [Color(0xFF1A3A3C), Color(0xFF134E4A)],
    phase2Gradient: [Color(0xFF1A3A3C), Color(0xFF134E4A)],
    useGlow: false,
  );

  LinearGradient get glacierHeroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: heroGradient,
      );

  LinearGradient get phase2GradientLinear => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: phase2Gradient,
      );

  @override
  ThriftyChefColors copyWith({bool? useGlow}) => this;

  @override
  ThriftyChefColors lerp(ThemeExtension<ThriftyChefColors>? other, double t) {
    if (other is! ThriftyChefColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension ThriftyChefThemeContext on BuildContext {
  ThriftyChefColors get fw =>
      Theme.of(this).extension<ThriftyChefColors>() ?? ThriftyChefColors.light;
}

/// Builds Material themes and provides decoration helpers.
class AppTheme {
  static const double maxContentWidth = 1140;
  static const double profileMaxWidth = 720;
  static const double cardRadius = 22;

  /// Synced from [AppState.themeMode] — do NOT mutate inside buildTheme().
  static bool isDark = false;

  static ThriftyChefColors get c => isDark ? ThriftyChefColors.dark : ThriftyChefColors.light;

  static Color get background => c.background;
  static Color get frost => c.frost;
  static Color get glacierDeep => c.glacierDeep;
  static Color get glacier => c.glacier;
  static Color get glacierMid => c.glacierMid;
  static Color get iceLight => c.iceLight;
  static Color get iceAccent => c.iceAccent;
  static Color get cyanBright => c.roseAccent;
  static Color get arcticGlow => c.arcticGlow;
  static Color get warningOrange => c.warningOrange;
  static Color get dangerRed => c.dangerRed;
  static Color get goodTeal => c.goodTeal;
  static Color get textDark => c.textPrimary;
  static Color get textMuted => c.textMuted;
  static Color get cardBorder => c.cardBorder;
  static Color get cardSurface => c.cardSurface;
  static Color get primaryGreen => c.glacier;
  static Color get lightGreen => c.iceLight;
  static Color get accentGreen => c.iceAccent;
  static Color get roseAccent => c.roseAccent;
  static LinearGradient get glacierHeroGradient => c.glacierHeroGradient;
  static LinearGradient get phase1Gradient => c.glacierHeroGradient;
  static LinearGradient get phase2Gradient => c.phase2GradientLinear;

  static void syncDarkMode(bool dark) => isDark = dark;

  static ThemeData buildTheme(Brightness brightness) {
    final palette = brightness == Brightness.dark ? ThriftyChefColors.dark : ThriftyChefColors.light;
    final isDarkTheme = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.glacier,
      brightness: brightness,
      primary: palette.glacier,
      onPrimary: Colors.white,
      secondary: palette.roseAccent,
      tertiary: palette.arcticGlow,
      surface: palette.cardSurface,
      onSurface: palette.textPrimary,
      error: palette.dangerRed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary),
        bodyLarge: TextStyle(fontSize: 15, color: palette.textPrimary, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: palette.textPrimary, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, color: palette.textMuted, height: 1.35),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: palette.cardBorder),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardSurface,
        hintStyle: TextStyle(color: palette.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.glacier, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.cardSurface,
        selectedColor: palette.iceLight,
        labelStyle: TextStyle(fontSize: 13, color: palette.textPrimary),
        secondaryLabelStyle: TextStyle(fontSize: 13, color: palette.glacier, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.cardBorder),
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.glacier,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.cardBorder,
          disabledForegroundColor: palette.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
              return palette.glacierDeep.withValues(alpha: 0.18);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.glacier,
          backgroundColor: isDarkTheme ? Colors.transparent : Colors.white,
          side: BorderSide(color: palette.glacier),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.glacier;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.iceAccent;
          return palette.cardBorder;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.cardSurface,
        indicatorColor: palette.iceLight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? palette.glacier : palette.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? palette.glacier : palette.textMuted, size: 22);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.cardSurface,
        indicatorColor: palette.iceAccent,
        selectedIconTheme: IconThemeData(color: palette.glacierDeep, size: 24),
        unselectedIconTheme: IconThemeData(color: palette.textMuted, size: 22),
        selectedLabelTextStyle: TextStyle(color: palette.glacierDeep, fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: palette.textMuted, fontSize: 12),
        useIndicator: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.glacier,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkTheme ? palette.frost : const Color(0xFFEAF8F8),
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary),
      ),
      dividerTheme: DividerThemeData(color: palette.cardBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: palette.glacierDeep,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.glacier),
    );
  }

  static ThemeData light() => buildTheme(Brightness.light);
  static ThemeData dark() => buildTheme(Brightness.dark);

  static BoxDecoration cardDecoration({Color? color, bool hoverable = false, Gradient? gradient}) {
    final palette = c;
    return BoxDecoration(
      color: gradient == null ? (color ?? palette.cardSurface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: palette.cardBorder),
      boxShadow: softShadow(elevated: hoverable),
    );
  }

  /// Soft glass-style hero — light teal wash, not solid teal.
  static BoxDecoration heroDecoration({Gradient? gradient}) {
    final palette = c;
    return BoxDecoration(
      gradient: gradient ?? palette.glacierHeroGradient,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.7)),
      boxShadow: softShadow(elevated: true),
    );
  }

  static BoxDecoration frostPanelDecoration() {
    final palette = c;
    return BoxDecoration(
      color: palette.iceLight,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: palette.cardBorder),
    );
  }

  /// Soft shadow: 0 8px 24px rgba(0,0,0,0.05)
  static List<BoxShadow> softShadow({bool elevated = false}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: elevated ? 0.07 : 0.05),
        blurRadius: elevated ? 28 : 24,
        offset: Offset(0, elevated ? 10 : 8),
      ),
    ];
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return const EdgeInsets.symmetric(horizontal: 32, vertical: 28);
    if (w >= 600) return const EdgeInsets.symmetric(horizontal: 24, vertical: 22);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 18);
  }
}
