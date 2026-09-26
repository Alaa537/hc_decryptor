import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg = Color(0xFF0B0F19);
  static const Color card = Color(0xFF151A26);
  static const Color accent = Color(0xFF00E5A0);
  static const Color accent2 = Color(0xFF7C5CFF);
  static const Color danger = Color(0xFFFF5470);
  static const Color text = Color(0xFFE6EAF2);
  static const Color muted = Color(0xFF8892A6);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent2,
        surface: card,
        error: danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: text, fontSize: 18, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
