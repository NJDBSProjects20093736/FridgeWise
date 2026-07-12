import 'package:flutter/material.dart';

/// Glacier / icy-blue product theme inspired by FridgeWise design references.
class AppTheme {
  // Core glacier palette
  static const Color background = Color(0xFFF0F7FC);
  static const Color frost = Color(0xFFE8F4FA);
  static const Color glacierDeep = Color(0xFF0F4C5C);
  static const Color glacier = Color(0xFF1A6B85);
  static const Color glacierMid = Color(0xFF2B8CAD);
  static const Color iceLight = Color(0xFFDCEEF7);
  static const Color iceAccent = Color(0xFF5BB8D4);
  static const Color cyanBright = Color(0xFF22D3EE);
  static const Color arcticGlow = Color(0xFF7DD3FC);

  // Semantic (unchanged — work on glacier backgrounds)
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color goodTeal = Color(0xFF14B8A6);

  // Text & surfaces
  static const Color textDark = Color(0xFF1E3A4F);
  static const Color textMuted = Color(0xFF5B7A8C);
  static const Color cardBorder = Color(0xFFC5D9E8);
  static const Color cardSurface = Colors.white;

  // Backward-compatible aliases (used across widgets)
  static const Color primaryGreen = glacier;
  static const Color lightGreen = iceLight;
  static const Color accentGreen = iceAccent;

  static const double maxContentWidth = 1140;
  static const double profileMaxWidth = 720;

  static const LinearGradient glacierHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A6B85), Color(0xFF0891B2)],
  );

  static const LinearGradient phase1Gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A6B85), Color(0xFF2B8CAD)],
  );

  static const LinearGradient phase2Gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
  );

  static const LinearGradient frostWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0F7FC), Color(0xFFE8F4FA)],
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: glacier,
      primary: glacier,
      onPrimary: Colors.white,
      secondary: cyanBright,
      tertiary: arcticGlow,
      surface: cardSurface,
      onSurface: textDark,
      error: dangerRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textDark, letterSpacing: -0.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
        bodyLarge: TextStyle(fontSize: 15, color: textDark, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: textDark, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, color: textMuted, height: 1.35),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glacierMid, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardSurface,
        selectedColor: iceLight,
        labelStyle: const TextStyle(fontSize: 13, color: textDark),
        secondaryLabelStyle: const TextStyle(fontSize: 13, color: glacier, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder),
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: glacier,
          foregroundColor: Colors.white,
          disabledBackgroundColor: cardBorder,
          disabledForegroundColor: textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: glacier,
          side: const BorderSide(color: cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return glacier;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return arcticGlow;
          return cardBorder;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardSurface,
        indicatorColor: iceLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? glacier : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? glacier : textMuted, size: 22);
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: cardSurface,
        indicatorColor: iceLight,
        selectedIconTheme: IconThemeData(color: glacier),
        unselectedIconTheme: IconThemeData(color: textMuted),
        selectedLabelTextStyle: TextStyle(color: glacier, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: textMuted, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: textDark,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
      ),
      dividerTheme: const DividerThemeData(color: cardBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: glacierDeep,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: glacier),
    );
  }

  static BoxDecoration cardDecoration({Color? color, bool hoverable = false, Gradient? gradient}) {
    return BoxDecoration(
      color: gradient == null ? (color ?? cardSurface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cardBorder.withValues(alpha: gradient != null ? 0.4 : 1)),
      boxShadow: hoverable
          ? [BoxShadow(color: glacier.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4))]
          : null,
    );
  }

  static BoxDecoration heroDecoration({Gradient? gradient}) {
    return BoxDecoration(
      gradient: gradient ?? glacierHeroGradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: glacier.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
      ],
    );
  }

  static BoxDecoration frostPanelDecoration() {
    return BoxDecoration(
      color: frost,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cardBorder),
    );
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (w >= 600) return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}
