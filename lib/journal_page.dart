import 'package:flutter/material.dart';
import 'day_widget.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F3), // Paper color
      body: SelectionArea(
        child: CustomScrollView(
          center: const ValueKey('today'),
          slivers: [
            // Past days (scroll up) - infinite
            SliverList.builder(
              itemBuilder: (context, index) {
                final date = today.subtract(Duration(days: index + 1));
                return DayWidget(date: date);
              },
            ),

            // Today (anchor point)
            SliverToBoxAdapter(
              key: const ValueKey('today'),
              child: DayWidget(date: today),
            ),

            // Future days (scroll down) - infinite
            SliverList.builder(
              itemBuilder: (context, index) {
                final date = today.add(Duration(days: index + 1));
                return DayWidget(date: date);
              },
            ),
          ],
        ),
      ),
    );
  }
}
