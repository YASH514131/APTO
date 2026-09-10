import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Seed Vault Official Palette
  static const Color background = Color(0xFF091112);      // Deep dark background
  static const Color cardBg = Color(0xFF131F21);          // Dark teal card background
  static const Color seedVaultTeal = Color(0xFF32616B);   // Seed Vault Accent Teal
  static const Color seedVaultTealHover = Color(0xFF3E7581);
  static const Color outlineBorder = Color(0xFF233639);   // Subtle pill button border
  static const Color slateGray = Color(0xFF767B7A);       // Muted text
  static const Color textPrimary = Color(0xFFFFFFFF);     // Pure white text
  static const Color textSecondary = Color(0xFF8B9899);   // Secondary muted text

  // Solana Highlights
  static const Color solanaGreen = Color(0xFF14F195);
  static const Color verifiedGreen = Color(0xFF14F195);
  static const Color solanaPurple = Color(0xFF9945FF);

  // Font Styles
  static TextStyle serifHeading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    double? letterSpacing,
  }) {
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      textStyle: const TextStyle(
        fontFamilyFallback: ['serif', 'Times New Roman', 'Georgia'],
      ),
    );
  }

  static TextStyle sansBody({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textSecondary,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      textStyle: const TextStyle(
        fontFamilyFallback: ['sans-serif', 'Roboto', 'Arial'],
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: seedVaultTeal,
        secondary: solanaGreen,
        surface: cardBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: serifHeading(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}
