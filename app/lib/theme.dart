import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens shared across the app. Lifted from the Bookmarked
/// design canvas so the real app matches the mockup exactly.
class AppColors {
  static const paper = Color(0xFFF7F2EA);
  static const paperSoft = Color(0xFFFBF7EF);
  static const ink = Color(0xFF2E2A22);
  static const inkSoft = Color(0xFF8A8171);
  static const line = Color(0xFFDFD6C2);
  static const lineStrong = Color(0xFFC7BFAE);
  static const green = Color(0xFF3F5D4E);
  static const greenSoft = Color(0xFFE4EAE3);
  static const terra = Color(0xFFA24E42);
  static const terraSoft = Color(0xFFF3E4E0);
  static const gold = Color(0xFFC9962F);
  static const creamDark = Color(0xFFEDE6D6);

  static const coverPalette = [green, terra, gold, Color(0xFF8E5B8A), Color(0xFF4A6B7A), Color(0xFF6B6248)];

  static Color coverFor(String seed) {
    var hash = 0;
    for (final ch in seed.codeUnits) {
      hash += ch;
    }
    return coverPalette[hash % coverPalette.length];
  }
}

class AppTheme {
  static TextStyle get display => GoogleFonts.spectral(color: AppColors.ink, fontStyle: FontStyle.italic);
  static TextStyle get serif => GoogleFonts.spectral(color: AppColors.ink);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.light),
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: GoogleFonts.manropeTextTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paperSoft,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lineStrong)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lineStrong)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green, width: 1.5)),
        hintStyle: GoogleFonts.manrope(color: AppColors.lineStrong),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.paperSoft,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paperSoft,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.spectral(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: GoogleFonts.manrope(color: AppColors.inkSoft, fontSize: 13),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.paperSoft,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.green,
        headerForegroundColor: AppColors.paperSoft,
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.green),
        todayBorder: const BorderSide(color: AppColors.green),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.paperSoft : AppColors.ink,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.green : null,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.paperSoft : AppColors.ink,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.green : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

const labelCapsStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
  color: AppColors.inkSoft,
);
