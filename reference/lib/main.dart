import 'package:flutter/material.dart';

import 'database/record_repository.dart';
import 'widgets/journal_screen.dart';

void main() {
  runApp(const LifelogReferenceApp());
}

class LifelogReferenceApp extends StatelessWidget {
  const LifelogReferenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lifelog (Reference)',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: JournalScreen(repository: SqliteRecordRepository()),
    );
  }
}
