// lib/core/theme/app_theme.dart
//
// Uygulama genelindeki Material3 tema tanımlaması.
// main.dart'ı sade tutmak için buraya çıkarıldı.

import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primary   = Color(0xFFE53935);
  static const Color _secondary = Color(0xFF263238);
  static const Color _surface   = Color(0xFFF8F9FA);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      primary:   _primary,
      secondary: _secondary,
      surface:   _surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    ),
  );
}
