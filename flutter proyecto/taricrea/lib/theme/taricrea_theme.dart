import 'package:flutter/material.dart';

const ink = Color(0xFF164C3D);
const accent = Color(0xFF079D7F);
const surface = Color(0xFFF7FAF8);
const mint = Color(0xFFE4F3ED);
const line = Color(0xFFD4E5DD);
const secondary = Color(0xFF50695F);

ThemeData taricreaTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ink).copyWith(
    primary: ink,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: ink,
    secondary: accent,
    outline: line,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: line),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
