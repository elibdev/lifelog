import 'package:flutter/material.dart';
import 'widgets/journal_screen.dart';

void main() {
  runApp(const LifelogApp());
}

class LifelogApp extends StatelessWidget {
  const LifelogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lifelog',
      theme: ThemeData(
        // Paper-like color scheme: warm, minimal, high contrast for readability
        colorScheme: ColorScheme.light(
          surface: const Color(0xFFFFFBF5), // Warm cream (paper color)
          onSurface: const Color(0xFF2B2B2B), // Dark gray text (ink)
          surfaceContainerHighest: const Color(0xFFF5F1EB), // Slightly darker cream for contrast
          primary: const Color(0xFF5B7C99), // Muted blue for accents
          onPrimary: Colors.white,
        ),

        // Typography: clean, readable fonts with good hierarchy
        textTheme: const TextTheme(
          // Date headers: medium size, semi-bold
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1.3,
          ),
          // Section titles (TODOS/NOTES): small, uppercase, spaced
          labelMedium: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.3,
            height: 1.2,
          ),
          // Body text: comfortable reading size with good line height
          bodyMedium: TextStyle(
            fontSize: 15,
            height: 1.6,
            letterSpacing: 0.15,
          ),
        ),

        // Checkbox theme for smoother, more refined appearance
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(
            color: Color(0xFF5B7C99),
            width: 1.5,
          ),
        ),

        useMaterial3: true,
      ),
      home: const JournalScreen(),
    );
  }
}
