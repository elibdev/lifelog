import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'daily_entry_field.dart';

class DailySliverGroup extends StatelessWidget {
  final DateTime date;
  const DailySliverGroup({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: DailyHeaderDelegate(date: date),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  DailyEntryField(date: date),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DailyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime date;
  DailyHeaderDelegate({required this.date});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final dateString = DateFormat('EEEE, MMM d, yyyy').format(date);

    return Container(
      color: Colors.grey[100],
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Text(dateString, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }

  @override
  double get maxExtent => 50.0;
  @override
  double get minExtent => 50.0;
  @override
  bool shouldRebuild(covariant DailyHeaderDelegate oldDelegate) =>
      date != oldDelegate.date;
}
