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
      // Use Material 3 with device default theme (respects system dark/light mode)
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system, // Follows device setting (dark mode on Mac)
      home: const JournalScreen(),
    );
  }
}
