import 'package:flutter/material.dart';
import 'daily_sliver_group.dart';

class JournalHomePage extends StatefulWidget {
  const JournalHomePage({super.key});

  @override
  State<JournalHomePage> createState() => _JournalHomePageState();
}

class _JournalHomePageState extends State<JournalHomePage> {
  final Key centerKey = const ValueKey('today-key');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      body: CustomScrollView(
        center: centerKey,
        slivers: [
          // The Past (Scrolling Up)
          for (int i = 1; i < 500; i++)
            DailySliverGroup(date: now.subtract(Duration(days: i))),

          // Today (The Center Anchor)
          DailySliverGroup(key: centerKey, date: now),

          // The Future (Scrolling Down)
          for (int i = 1; i < 500; i++)
            DailySliverGroup(date: now.add(Duration(days: i))),
        ],
      ),
    );
  }
}
