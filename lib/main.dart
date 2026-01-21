import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'journal_home.dart';

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
        // Using a soft teal seed to match the minimal journal aesthetic.
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          background: const Color(0xFFF5F5F5), // Light grey background
        ),
        useMaterial3: true,
        // Global scaffold background for the entire app.
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const JournalHomePage(),
    );
  }
}
