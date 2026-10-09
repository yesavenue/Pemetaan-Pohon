import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet resmi "Modern Government GIS" — navy sebagai identitas
/// kedinasan, hijau sebagai aksen lingkungan (bukan warna dominan),
/// gold sebagai aksen sekunder tipis.
class AppColors {
  static const navy = Color(0xFF0B3554);
  static const navyDark = Color(0xFF082943);
  static const leaf = Color(0xFF2E7D5B);
  static const background = Color(0xFFF4F7F6);
  static const white = Color(0xFFFFFFFF);
  static const gold = Color(0xFFD6B45A);

  // Warna status kondisi pohon.
  static const sehat = Color(0xFF2E9B68);
  static const sakit = Color(0xFFE1B919);
  static const rawanTumbang = Color(0xFFE05252);

  // Alias supaya kode lama yang masih memakai nama "paper" tetap jalan.
  static const paper = background;
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    secondary: AppColors.leaf,
    brightness: Brightness.light,
  );

  final baseTextTheme = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: baseTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: AppColors.navy,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE5E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.leaf, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        animationDuration: const Duration(milliseconds: 140),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        animationDuration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: AppColors.leaf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: IconThemeData(color: AppColors.navy),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFDCE5E0),
      thickness: 1,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Color(0xFFE9F3ED),
      side: BorderSide(color: Color(0xFFDCE5E0)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDCE5E0)),
      ),
    ),
  );
}
