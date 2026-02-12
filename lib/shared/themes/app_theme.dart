import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme Configuration
class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  static const Color secondaryColor = Color(0xFF10B981); // Emerald
  static const Color secondaryDark = Color(0xFF059669);
  static const Color secondaryLight = Color(0xFF34D399);

  static const Color accentColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF10B981);
  static const Color infoColor = Color(0xFF3B82F6);

  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textWhite = Colors.white;

  static const Color dividerColor = Color(0xFFE5E7EB);
  static const Color borderColor = Color(0xFFD1D5DB);

  // Dark mode colors
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCard = Color(0xFF1E293B); // Slate 800
  static const Color darkTextPrimary = Color(0xFFE2E8F0); // Slate 200
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextTertiary = Color(0xFF64748B); // Slate 500
  static const Color darkDivider = Color(0xFF334155); // Slate 700
  static const Color darkBorder = Color(0xFF334155); // Slate 700

  // AI specific colors
  static const Color aiPrimary = Color(0xFF8B5CF6); // Purple for AI
  static const Color aiSecondary = Color(0xFFA78BFA);
  static const Color aiBackground = Color(0xFFF5F3FF);

  // Trust level colors
  static const Color trustLevelInform = Color(0xFF3B82F6); // Blue
  static const Color trustLevelSuggest = Color(0xFFF59E0B); // Amber
  static const Color trustLevelAuto = Color(0xFF10B981); // Green
  static const Color trustLevelSilent = Color(0xFF8B5CF6); // Purple

  // Typography
  static TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textPrimary,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: textPrimary,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: textSecondary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textSecondary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: textTertiary,
    ),
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    cardTheme: const CardTheme(
      color: cardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textTertiary,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: dividerColor,
      thickness: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: backgroundColor,
      selectedColor: primaryColor,
      labelStyle: GoogleFonts.inter(fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );

  // Dark Typography
  static TextTheme darkTextTheme = TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: darkTextPrimary,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: darkTextPrimary,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: darkTextPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: darkTextPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: darkTextPrimary,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: darkTextPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: darkTextPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: darkTextPrimary,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: darkTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: darkTextPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: darkTextPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: darkTextSecondary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: darkTextPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: darkTextSecondary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: darkTextTertiary,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: darkBackground,
    textTheme: darkTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
      ),
    ),
    cardTheme: const CardTheme(
      color: darkCard,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: darkBorder),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: darkTextTertiary,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkDivider,
      thickness: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkSurface,
      selectedColor: primaryColor,
      labelStyle: GoogleFonts.inter(fontSize: 12, color: darkTextPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return darkTextTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor.withValues(alpha: 0.5);
        return darkBorder;
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: darkSurface,
      selectedIconTheme: const IconThemeData(color: primaryColor),
      unselectedIconTheme: IconThemeData(color: darkTextSecondary),
      selectedLabelTextStyle: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: GoogleFonts.inter(color: darkTextSecondary),
    ),
  );

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border Radius
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;
  static const double radiusFull = 9999.0;

  // Shadow
  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Context-aware color helpers (respect dark mode) ───
  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surface(BuildContext context) =>
      Theme.of(context).cardTheme.color ?? cardColor;

  static Color card(BuildContext context) =>
      Theme.of(context).cardTheme.color ?? cardColor;

  static Color text(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? textPrimary;

  static Color textSec(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.color ?? textSecondary;

  static Color border(BuildContext context) =>
      Theme.of(context).dividerTheme.color ?? borderColor;

  static Color divider(BuildContext context) =>
      Theme.of(context).dividerTheme.color ?? dividerColor;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
