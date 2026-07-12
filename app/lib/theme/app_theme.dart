import 'package:flutter/material.dart';

/// Semantic FridgeWise palette — Light (Frost) and Dark (Nordic Rose & Frost).
@immutable
class FridgeWiseColors extends ThemeExtension<FridgeWiseColors> {
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

  const FridgeWiseColors({
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

  /// Light mode — pale frost dashboard (design ref: light mockup).
  static const light = FridgeWiseColors(
    background: Color(0xFFF1F5F9),
    frost: Color(0xFFF8FAFC),
    glacierDeep: Color(0xFF0369A1),
    glacier: Color(0xFF0284C7),
    glacierMid: Color(0xFF0EA5E9),
    iceLight: Color(0xFFE0F2FE),
    iceAccent: Color(0xFF7DD3FC),
    roseAccent: Color(0xFFE5A99E),
    arcticGlow: Color(0xFF0EA5E9),
    warningOrange: Color(0xFFD97706),
    dangerRed: Color(0xFFDC2626),
    goodTeal: Color(0xFF0D9488),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    cardBorder: Color(0xFFE2E8F0),
    cardSurface: Color(0xFFFFFFFF),
    heroGradient: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
    phase2Gradient: [Color(0xFF0EA5E9), Color(0xFF7DD3FC)],
    useGlow: false,
  );

  /// Dark mode — Nordic Rose & Frost (design ref: frost-heavy dark mockup).
  static const dark = FridgeWiseColors(
    background: Color(0xFF0B1220),
    frost: Color(0xFF131C2E),
    glacierDeep: Color(0xFF0C4A6E),
    glacier: Color(0xFF38BDF8),
    glacierMid: Color(0xFF22D3EE),
    iceLight: Color(0xFF1E3A5F),
    iceAccent: Color(0xFF0EA5E9),
    roseAccent: Color(0xFFE8A598),
    arcticGlow: Color(0xFF22D3EE),
    warningOrange: Color(0xFFF59E0B),
    dangerRed: Color(0xFFEF4444),
    goodTeal: Color(0xFF10B981),
    textPrimary: Color(0xFFF1F5F9),
    textMuted: Color(0xFF94A3B8),
    cardBorder: Color(0xFF334155),
    cardSurface: Color(0xFF151F32),
    heroGradient: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
    phase2Gradient: [Color(0xFF22D3EE), Color(0xFF67E8F9)],
    useGlow: true,
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
  FridgeWiseColors copyWith({bool? useGlow}) => this;

  @override
  FridgeWiseColors lerp(ThemeExtension<FridgeWiseColors>? other, double t) {
    if (other is! FridgeWiseColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension FridgeWiseThemeContext on BuildContext {
  FridgeWiseColors get fw =>
      Theme.of(this).extension<FridgeWiseColors>() ?? FridgeWiseColors.light;
}

/// Builds Material themes and provides decoration helpers.
class AppTheme {
  static const double maxContentWidth = 1140;
  static const double profileMaxWidth = 720;

  /// Synced from [AppState.themeMode] — do NOT mutate inside buildTheme().
  static bool isDark = false;

  static FridgeWiseColors get c => isDark ? FridgeWiseColors.dark : FridgeWiseColors.light;

  // Backward-compatible accessors (used across widgets)
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
    final palette = brightness == Brightness.dark ? FridgeWiseColors.dark : FridgeWiseColors.light;
    final isDarkTheme = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.glacier,
      brightness: brightness,
      primary: palette.glacier,
      onPrimary: isDarkTheme ? palette.background : Colors.white,
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
          fontSize: 22,
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: palette.useGlow ? palette.glacier.withValues(alpha: 0.35) : palette.cardBorder,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardSurface,
        hintStyle: TextStyle(color: palette.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
          foregroundColor: isDarkTheme ? palette.background : Colors.white,
          disabledBackgroundColor: palette.cardBorder,
          disabledForegroundColor: palette.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.glacier,
          side: BorderSide(color: palette.useGlow ? palette.glacier.withValues(alpha: 0.5) : palette.cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.glacier;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.arcticGlow;
          return palette.cardBorder;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.cardSurface,
        indicatorColor: palette.iceLight,
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
        backgroundColor: palette.frost,
        indicatorColor: palette.iceLight,
        selectedIconTheme: IconThemeData(color: palette.glacier),
        unselectedIconTheme: IconThemeData(color: palette.textMuted),
        selectedLabelTextStyle: TextStyle(color: palette.glacier, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: palette.textMuted, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary),
      ),
      dividerTheme: DividerThemeData(color: palette.cardBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: palette.useGlow
            ? palette.glacier.withValues(alpha: hoverable ? 0.55 : 0.35)
            : palette.cardBorder,
      ),
      boxShadow: _shadows(palette, hoverable: hoverable),
    );
  }

  static BoxDecoration heroDecoration({Gradient? gradient}) {
    final palette = c;
    return BoxDecoration(
      gradient: gradient ?? palette.glacierHeroGradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: palette.useGlow
          ? [
              BoxShadow(color: palette.arcticGlow.withValues(alpha: 0.45), blurRadius: 20, spreadRadius: 0),
              BoxShadow(color: palette.glacier.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
            ]
          : [
              BoxShadow(color: palette.glacier.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
            ],
    );
  }

  static BoxDecoration frostPanelDecoration() {
    final palette = c;
    return BoxDecoration(
      color: palette.frost,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: palette.useGlow ? palette.glacier.withValues(alpha: 0.25) : palette.cardBorder,
      ),
      boxShadow: palette.useGlow
          ? [BoxShadow(color: palette.arcticGlow.withValues(alpha: 0.12), blurRadius: 12)]
          : null,
    );
  }

  static List<BoxShadow>? _shadows(FridgeWiseColors palette, {bool hoverable = false}) {
    if (palette.useGlow) {
      return [
        BoxShadow(
          color: palette.arcticGlow.withValues(alpha: hoverable ? 0.35 : 0.2),
          blurRadius: hoverable ? 16 : 10,
          spreadRadius: 0,
        ),
      ];
    }
    if (hoverable) {
      return [
        BoxShadow(color: palette.glacier.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4)),
      ];
    }
    return null;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (w >= 600) return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}
