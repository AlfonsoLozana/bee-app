import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  static const bg          = Color(0xFF0A0A0F);
  static const surface     = Color(0xFF111118);
  static const surface2    = Color(0xFF16161F);
  static const surface3    = Color(0xFF1C1C28);
  static const textPrimary = Color(0xFFE8E8F0);
  static const textMuted   = Color(0xFF8888A0);
  static const textFaint   = Color(0xFF4A4A60);
  static const primary     = Color(0xFF7C6AF7);
  static const primaryDim  = Color(0x1F7C6AF7);
  static const cyan        = Color(0xFF22D3EE);
  static const success     = Color(0xFF34D399);
  static const warning     = Color(0xFFF59E0B);
  static const danger      = Color(0xFFF87171);
  static const border      = Color(0x12FFFFFF);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        color: AppColors.textPrimary, fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: AppColors.textPrimary, fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textFaint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}