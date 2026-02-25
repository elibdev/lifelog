import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../constants/grid_constants.dart';
import '../../services/date_service.dart';
import 'record_text_field.dart';

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
  // C2: prevents editing/toggling in read-only contexts (e.g. search results)
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

    // C1: Present the habit name via RecordTextField so it's editable after
    // a /habit slash command creates the record. The trick: RecordTextField
    // works on record.content, so we pass a view where content = habitName,
    // then intercept onSave to write the new name back to habit.name metadata.
    final habitNameRecord = record.copyWith(content: record.habitName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circular completion indicator — C2: onTap is null when readOnly
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          child: SizedBox(
            width: GridConstants.checkboxSize,
            height: GridConstants.rowHeight,
            child: Center(
              child: GestureDetector(
                onTap: readOnly ? null : _toggleCompletion,
                child: Icon(
                  completedToday
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: GridConstants.checkboxSize,
                  color: completedToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
        // C1: Habit name is now editable via RecordTextField.
        // onSave remaps content → habit.name metadata so the name persists.
        Expanded(
          child: RecordTextField(
            record: habitNameRecord,
            onSave: (updated) =>
                onSave(record.copyWithMetadata({'habit.name': updated.content})),
            onDelete: onDelete,
            onSubmitted: onSubmitted,
            recordIndex: recordIndex,
            onFocusNodeCreated: onFocusNodeCreated,
            onFocusNodeDisposed: onFocusNodeDisposed,
            readOnly: readOnly,
          ),
        ),
        // Streak/total metadata — right-aligned
        Padding(
          padding: const EdgeInsets.only(left: 8),
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
