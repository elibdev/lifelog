import 'package:flutter/material.dart';
import 'widgets/journal_screen.dart';
import 'database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database path (async operation required before using database)
  await DatabaseProvider.instance.initialize();

  runApp(const LifelogApp());
}

class LifelogApp extends StatelessWidget {
  const LifelogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lifelog',

      // Flutter Theming: MaterialApp accepts separate themes for light/dark modes
      // and automatically switches based on themeMode setting. Material 3 uses
      // ColorScheme to define all app colors consistently.
      // See: https://docs.flutter.dev/ui/design/material/material-3

      theme: ThemeData(
        useMaterial3: true,
        // ColorScheme.fromSeed() generates a complete color palette from one color,
        // but we override specific colors to reduce contrast and add warmth
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
          // surface: used by Cards, Dialogs, BottomSheets, etc.
          // Using warm off-white (#FAF9F7) instead of pure white
          surface: const Color(0xFFFAF9F7),
        ),
        // scaffoldBackgroundColor: The main app background color
        // Slightly different from surface to create subtle depth
        scaffoldBackgroundColor: const Color(0xFFF5F4F2),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          // Using warm dark gray (#1E1E1E) instead of pure black (#000000)
          // This reduces eye strain and feels less cold
          surface: const Color(0xFF1E1E1E),
        ),
        // Slightly darker than surface for background depth
        scaffoldBackgroundColor: const Color(0xFF181818),
      ),

      // ThemeMode.system: Flutter checks MediaQuery.platformBrightnessOf(context)
      // to automatically switch between theme and darkTheme
      themeMode: ThemeMode.system,
      home: const JournalScreen(),
    );
  }
}
