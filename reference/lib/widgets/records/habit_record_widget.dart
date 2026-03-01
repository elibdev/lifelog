import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'package:lifelog_reference/services/date_service.dart';

/// Renders a habit record with name, streak count, and tap-to-complete action.
///
/// Habits are recurring records that track daily/weekly completions.
/// Tapping the checkmark adds today's date to the completions list.
class HabitRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;
  // C2: prevents toggling in read-only contexts (e.g. search results)
  final bool readOnly;

  const HabitRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
    this.readOnly = false,
  });

  // M6: Check completion for the record's own date, not always today.
  // This allows retroactive journaling on past days.
  bool get _isCompletedForDate {
    return record.habitCompletions.contains(record.date);
  }

  // P6: Streak uses a Set for O(1) lookups — was O(n²) with List.contains inside a loop.
  // Streak always counts backward from today (current streak, not historical).
  int get _currentStreak {
    final completions = Set<String>.from(record.habitCompletions);
    if (completions.isEmpty) return 0;

    int streak = 0;
    var checkDate = DateService.today();

    while (completions.contains(checkDate)) {
      streak++;
      checkDate = DateService.getPreviousDate(checkDate);
    }
    return streak;
  }

  // M6: Toggle completion for record.date, not today.
  void _toggleCompletion() {
    final date = record.date;
    final completions = record.habitCompletions.toList();

    if (completions.contains(date)) {
      completions.remove(date);
    } else {
      completions.add(date);
    }

    // Namespaced metadata key: "habit.completions"
    final updated = record.copyWithMetadata({'habit.completions': completions});
    onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedForDate = _isCompletedForDate;
    final streak = _currentStreak;
    final totalCompletions = record.habitCompletions.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          // ConstrainedBox ensures the icon column is at least as tall as one
          // line of body text so the icon is vertically centred on single-line
          // habits, while still pinning to the top on wrapping names.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: GridConstants.checkboxSize * GridConstants.textLineHeightMultiplier,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              // M5: 44×44 minimum tap target (HIG / Material) around the 20px visual icon.
              // GestureDetector fills the SizedBox, giving full 44×44 hit area.
              child: SizedBox(
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: readOnly ? null : _toggleCompletion,
                  child: Center(
                    child: Icon(
                      completedForDate
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: GridConstants.checkboxSize,
                      color: completedForDate
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            record.habitName.isNotEmpty ? record.habitName : record.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: GridConstants.textLineHeightMultiplier,
              fontWeight: completedForDate ? FontWeight.w500 : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            streak > 0 ? '$streak streak · $totalCompletions total' : '$totalCompletions total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: streak > 0
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.outline,
              fontWeight: streak > 0 ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }
}
