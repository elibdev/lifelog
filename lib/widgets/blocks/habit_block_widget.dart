import 'package:flutter/material.dart';
import '../../models/block.dart';
import '../../constants/grid_constants.dart';
import '../../services/date_service.dart';

/// Renders a habit block with name, streak count, and tap-to-complete action.
///
/// Habits are recurring blocks that track daily/weekly completions.
/// Tapping the checkmark adds today's date to the completions list.
class HabitBlockWidget extends StatelessWidget {
  final Block block;
  final Function(Block) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? blockIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const HabitBlockWidget({
    super.key,
    required this.block,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.blockIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  bool get _isCompletedToday {
    final today = DateService.today();
    return block.habitCompletions.contains(today);
  }

  int get _currentStreak {
    final completions = block.habitCompletions.toList()..sort();
    if (completions.isEmpty) return 0;

    int streak = 0;
    var checkDate = DateService.today();

    // Walk backwards from today counting consecutive days
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
    final completions = block.habitCompletions.toList();

    if (completions.contains(today)) {
      completions.remove(today);
    } else {
      completions.add(today);
    }

    final updated = block.copyWithMetadata({'completions': completions});
    onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedToday = _isCompletedToday;
    final streak = _currentStreak;
    final totalCompletions = block.habitCompletions.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tap-to-complete button
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
        // Habit name
        Expanded(
          child: Text(
            block.habitName.isNotEmpty ? block.habitName : block.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: GridConstants.textLineHeightMultiplier,
              fontWeight: completedToday ? FontWeight.bold : null,
            ),
          ),
        ),
        // Streak and total count
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            streak > 0 ? '🔥$streak · $totalCompletions total' : '$totalCompletions total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
