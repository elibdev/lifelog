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

  const HabitRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  bool get _isCompletedToday {
    final today = DateService.today();
    return record.habitCompletions.contains(today);
  }

  int get _currentStreak {
    final completions = record.habitCompletions.toList()..sort();
    if (completions.isEmpty) return 0;

    int streak = 0;
    var checkDate = DateService.today();

    for (int i = 0; i < completions.length; i++) {
      if (completions.contains(checkDate)) {
        streak++;
        checkDate = DateService.getPreviousDate(checkDate);
      } else {
        break;
      }
    }
    return streak;
  }

  void _toggleCompletion() {
    final today = DateService.today();
    final completions = record.habitCompletions.toList();

    if (completions.contains(today)) {
      completions.remove(today);
    } else {
      completions.add(today);
    }

    // Namespaced metadata key: "habit.completions"
    final updated = record.copyWithMetadata({'habit.completions': completions});
    onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedToday = _isCompletedToday;
    final streak = _currentStreak;
    final totalCompletions = record.habitCompletions.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          child: SizedBox(
            width: GridConstants.checkboxSize,
            height: GridConstants.checkboxSize,
            child: GestureDetector(
              onTap: _toggleCompletion,
              child: Icon(
                completedToday ? Icons.check_circle : Icons.circle_outlined,
                size: GridConstants.checkboxSize,
                color: completedToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            record.habitName.isNotEmpty ? record.habitName : record.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: GridConstants.textLineHeightMultiplier,
              fontWeight: completedToday ? FontWeight.bold : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            streak > 0 ? '$streak streak · $totalCompletions total' : '$totalCompletions total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
