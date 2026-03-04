import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'package:lifelog_reference/services/date_service.dart';

/// Renders a habit record with name, streak count, and tap-to-complete action.
///
/// Habits are recurring records that track daily/weekly completions.
/// Tapping the checkmark adds today's date to the completions list.
///
/// StatefulWidget is required here to own the TextEditingController for the
/// habit name field — controllers must be disposed, so they live in State.
/// See: https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html
class HabitRecordWidget extends StatefulWidget {
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

  @override
  State<HabitRecordWidget> createState() => _HabitRecordWidgetState();
}

class _HabitRecordWidgetState extends State<HabitRecordWidget> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Initialize from metadata; fall back to content for legacy records.
    _nameController = TextEditingController(
      text: widget.record.habitName.isNotEmpty
          ? widget.record.habitName
          : widget.record.content,
    );
  }

  // didUpdateWidget fires when the parent rebuilds with a new Record instance.
  // Sync only when the name actually changed externally (e.g. undo), not on
  // every keystroke (which would fight the user's cursor position).
  // See: https://api.flutter.dev/flutter/widgets/State/didUpdateWidget.html
  @override
  void didUpdateWidget(HabitRecordWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = widget.record.habitName.isNotEmpty
        ? widget.record.habitName
        : widget.record.content;
    if (newName != _nameController.text) {
      _nameController.text = newName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // M6: Check completion for the record's own date, not always today.
  // This allows retroactive journaling on past days.
  bool get _isCompletedForDate {
    return widget.record.habitCompletions.contains(widget.record.date);
  }

  // P6: Streak uses a Set for O(1) lookups — was O(n²) with List.contains inside a loop.
  // Streak always counts backward from today (current streak, not historical).
  int get _currentStreak {
    final completions = Set<String>.from(widget.record.habitCompletions);
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
    final date = widget.record.date;
    final completions = widget.record.habitCompletions.toList();

    if (completions.contains(date)) {
      completions.remove(date);
    } else {
      completions.add(date);
    }

    // Namespaced metadata key: "habit.completions"
    final updated =
        widget.record.copyWithMetadata({'habit.completions': completions});
    widget.onSave(updated);
  }

  void _handleNameChanged(String value) {
    // Write the new name back into metadata so it persists across rebuilds.
    final updated =
        widget.record.copyWithMetadata({'habit.name': value});
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedForDate = _isCompletedForDate;
    final streak = _currentStreak;
    final totalCompletions = widget.record.habitCompletions.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          // M5: 44×44 minimum tap target (HIG / Material) around the 20px visual icon.
          // GestureDetector fills the SizedBox, giving full 44×44 hit area.
          child: SizedBox(
            width: GridConstants.minTouchTarget,
            height: GridConstants.minTouchTarget,
            child: GestureDetector(
              onTap: widget.readOnly ? null : _toggleCompletion,
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
        Expanded(
          // C2: Habit name is now editable via a plain TextField.
          // Writes back to metadata['habit.name'] on every change.
          child: TextField(
            controller: _nameController,
            readOnly: widget.readOnly,
            onChanged: widget.readOnly ? null : _handleNameChanged,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: GridConstants.textLineHeightMultiplier,
              fontWeight: completedForDate ? FontWeight.w500 : null,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              hintText: widget.readOnly ? null : 'Habit name…',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                height: GridConstants.textLineHeightMultiplier,
              ),
            ),
            maxLines: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            streak > 0
                ? '$streak streak · $totalCompletions total'
                : '$totalCompletions total',
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
