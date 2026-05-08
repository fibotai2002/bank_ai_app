import 'package:flutter/material.dart';

// ── Google Material You ranglar ───────────────────────────────────────────────
class AppColors {
  // Google asosiy ranglar (premium variantlar)
  static const googleBlue   = Color(0xFF1A73E8);
  static const googleRed    = Color(0xFFD93025);
  static const googleYellow = Color(0xFFF9AB00);
  static const googleGreen  = Color(0xFF1E8E3E);

  // Light mode (Premium)
  static const bg           = Color(0xFFFDFDFD);
  static const surface      = Color(0xFFFFFFFF);
  static const surfaceVar   = Color(0xFFF1F3F4);
  static const border       = Color(0xFFE8EAED);
  static const accent       = Color(0xFF1A73E8);
  static const accentLight  = Color(0xFFE8F0FE);
  static const success      = Color(0xFF1E8E3E);
  static const warning      = Color(0xFFF9AB00);
  static const error        = Color(0xFFD93025);
  static const textPrimary  = Color(0xFF202124);
  static const textSec      = Color(0xFF5F6368);
  static const textHint     = Color(0xFF70757A);

  // Dark mode (Premium Deep Black)
  static const darkBg       = Color(0xFF000000);
  static const darkSurface  = Color(0xFF121212);
  static const darkSurface2 = Color(0xFF1E1E1E);
  static const darkBorder   = Color(0xFF2D2D2D);
  static const darkText     = Color(0xFFE8EAED);
  static const darkTextSec  = Color(0xFF9AA0A6);
  static const darkAccent   = Color(0xFF8AB4F8);

  // Glassmorphism colors
  static const glassBg      = Color(0xCCFFFFFF);
  static const glassDarkBg  = Color(0xCC121212);
  static const glassBorder  = Color(0x33FFFFFF);

  // Nav bar colors per tab (Google style)
  static const navColors = [
    googleBlue,    // Dashboard
    googleRed,     // AI Chat
    googleGreen,   // Vazifalar
    googleYellow,  // Xodimlar
    googleBlue,    // Hujjatlar
    googleRed,     // Xabarlar
    googleGreen,   // Profil
  ];
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.googleGreen,
      tertiary: AppColors.googleYellow,
      error: AppColors.error,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x1A000000),
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accentLight,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textHint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: CircleBorder(),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w800,
        color: AppColors.textPrimary, letterSpacing: -1.0,
      ),
      headlineMedium: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w700,
        color: AppColors.textPrimary, letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.textSec, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.textHint),
      labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: AppColors.textPrimary, letterSpacing: 0.1,
      ),
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: ColorScheme.dark(
      primary: AppColors.darkAccent,
      secondary: AppColors.googleGreen,
      tertiary: AppColors.googleYellow,
      error: AppColors.googleRed,
      surface: AppColors.darkSurface,
      onPrimary: AppColors.darkBg,
      onSurface: AppColors.darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x40000000),
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.darkText),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: AppColors.darkBorder,
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.darkTextSec, fontSize: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkAccent,
        foregroundColor: AppColors.darkBg,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurface2,
      selectedColor: AppColors.darkAccent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.darkText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBg,
      selectedItemColor: AppColors.darkAccent,
      unselectedItemColor: AppColors.darkTextSec,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkAccent,
      foregroundColor: AppColors.darkBg,
      elevation: 2,
      shape: CircleBorder(),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w800,
        color: AppColors.darkText, letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700,
        color: AppColors.darkText, letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.darkText),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.darkTextSec),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.darkTextSec),
      labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
    ),
  );
}
