import 'package:flutter/material.dart';

const ink = Color(0xFF14221F);
const tide = Color(0xFF1F6F68);
const tideDeep = Color(0xFF0E3D38);
const sand = Color(0xFFF6F1E7);
const card = Color(0xFFFFFCF7);
const coral = Color(0xFFE36A4A);
const line = Color(0xFFE4D9C8);
const muted = Color(0xFF5E6A66);

ThemeData quayTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: sand,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tide,
      primary: tide,
      onPrimary: card,
      secondary: coral,
      surface: card,
      onSurface: ink,
    ),
  );
  final outfit = base.textTheme.apply(
    fontFamily: 'Outfit',
    bodyColor: ink,
    displayColor: ink,
  );
  return base.copyWith(
    textTheme: outfit.copyWith(
      headlineMedium: outfit.headlineMedium?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleLarge: outfit.titleLarge?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: sand,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: tide, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tideDeep,
        foregroundColor: card,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
  );
}
