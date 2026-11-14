import 'package:material_ui/material_ui.dart';

const ink = Color(0xFF121110);
const panel = Color(0xFF1C1A18);
const panel2 = Color(0xFF26231F);
const line = Color(0xFF34302B);
const cream = Color(0xFFF4EFE6);
const muted = Color(0xFFA39C90);
const amber = Color(0xFFFFB547);
const coral = Color(0xFFFF7A59);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: amber,
    brightness: Brightness.dark,
    primary: amber,
    secondary: coral,
    surface: panel,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: ink,
      foregroundColor: cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w800, color: cream),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: amber,
      inactiveTrackColor: line,
      thumbColor: amber,
      trackHeight: 3,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: panel2,
      side: const BorderSide(color: line),
      labelStyle: const TextStyle(color: cream, fontWeight: FontWeight.w600, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: amber,
        foregroundColor: ink,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
