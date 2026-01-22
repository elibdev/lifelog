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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const JournalScreen(),
    );
  }
}
