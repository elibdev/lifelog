import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'daily_entry_field.dart';
import 'state/journal_state_registry.dart';
import 'state/daily_state_manager.dart';

class DailySliverGroup extends StatelessWidget {
  final DateTime date;
  const DailySliverGroup({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    // Get the state manager to check if date is empty
    final registry = context.read<JournalStateRegistry>();
    final stateManager = registry.getOrCreateManager(date);

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DailyEntryField(date: date),
                  // Conditional padding based on whether the date has content
                  ChangeNotifierProvider<DailyStateManager>.value(
                    value: stateManager,
                    child: Consumer<DailyStateManager>(
                      builder: (context, manager, _) {
                        final isEmpty = manager.state.isEmpty;
                        return SizedBox(height: isEmpty ? 8 : 32);
                      },
                    ),
                  ),
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
    final dateString = DateFormat('EEEE, MMM d, yyyy').format(date);

    return Container(
      color: const Color(0xFFF5F0E8),
      alignment: Alignment.centerLeft,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 8.0),
            child: SelectableText(
              dateString,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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
