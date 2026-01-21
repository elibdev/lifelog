import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'journal_page.dart';

void main() async {
  // Required to ensure plugin tools (like path_provider and sqflite)
  // are initialized before the app runs.
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize the database singleton.
  await JournalDatabase.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lifelog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7355), // Warm brown
          surface: const Color(0xFFFAF8F3), // Cream/paper color
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF8F3), // Cream paper
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            letterSpacing: 0.1,
            color: Color(0xFF2C2416),
          ),
          titleMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            letterSpacing: 0.1,
            color: Color(0xFF2C2416),
          ),
        ),
      ),
      home: const JournalPage(),
    );
  }
}
