import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../constants/grid_constants.dart';
import '../../services/date_service.dart';

/// Renders a habit record with circular completion indicator and streak info.
///
/// Design: The circle icon acts as a tap target for toggling today's
/// completion. Streak info uses the warm amber accent color when active,
/// giving it warmth reminiscent of Italian design.
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
        // Circular completion indicator
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          child: SizedBox(
            width: GridConstants.checkboxSize + 2,
            height: GridConstants.rowHeight,
            child: Center(
              child: GestureDetector(
                onTap: _toggleCompletion,
                child: Icon(
                  completedToday
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: GridConstants.checkboxSize + 2,
                  color: completedToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
        // Habit name
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: (GridConstants.rowHeight - 15 * 1.5) / 2,
            ),
            child: Text(
              record.habitName.isNotEmpty ? record.habitName : record.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: completedToday ? FontWeight.w500 : null,
                height: GridConstants.textLineHeightMultiplier,
              ),
            ),
          ),
        ),
        // Streak/total metadata — right-aligned
        Padding(
          padding: EdgeInsets.only(
            top: (GridConstants.rowHeight - 12 * 1.4) / 2,
            left: 8,
          ),
          child: Text(
            streak > 0
                ? '$streak streak · $totalCompletions total'
                : '$totalCompletions total',
            style: theme.textTheme.bodySmall?.copyWith(
              // Active streaks use the warm amber accent — Italian warmth
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
