import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet resmi "Modern Government GIS" — navy sebagai identitas
/// kedinasan, hijau sebagai aksen lingkungan (bukan warna dominan),
/// gold sebagai aksen sekunder tipis.
class AppColors {
  static const navy = Color(0xFF0B3554);
  static const navyDark = Color(0xFF082943);
  static const leaf = Color(0xFF2E7D5B);
  static const background = Color(0xFFF5F7F8);
  static const white = Color(0xFFFFFFFF);
  static const gold = Color(0xFFD6B45A);

  // Warna status kondisi pohon.
  static const sehat = Color(0xFF2E9B68);
  static const sakit = Color(0xFFF2A33A);
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
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
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
      selectedLabelTextStyle: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.black12),
      ),
    ),
  );
}