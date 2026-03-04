import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../notifications/navigation_notifications.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a plain text record.
///
/// No leading indicator — delegates entirely to [RecordTextField].
/// The TypePickerButton gutter is owned by [AdaptiveRecordWidget].
class TextRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;
  final bool readOnly;

  const TextRecordWidget({
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
  Widget build(BuildContext context) {
    return RecordTextField(
      record: record,
      onSave: onSave,
      onDelete: onDelete,
      onSubmitted: onSubmitted,
      recordIndex: recordIndex,
      onFocusNodeCreated: onFocusNodeCreated,
      onFocusNodeDisposed: onFocusNodeDisposed,
      readOnly: readOnly,
    );
  }
}

/// A small `+` icon in the leading gutter that opens a record-type picker.
///
/// Converts the current text record to any other type, preserving content
/// where meaningful. Uses [PopupMenuButton] — a Material widget that manages
/// its own overlay state, so no StatefulWidget is needed here.
/// See: https://api.flutter.dev/flutter/material/PopupMenuButton-class.html
class TypePickerButton extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;

  const TypePickerButton({super.key, required this.record, required this.onSave});

  // Converts to a new type, preserving content where the target type uses it.
  // Habit is the exception: content becomes the habit name (stored in metadata).
  Record _convertTo(RecordType type) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return switch (type) {
      RecordType.text => record.copyWith(
          type: RecordType.text,
          metadata: {},
          updatedAt: now,
        ),
      RecordType.todo => record.copyWith(
          type: RecordType.todo,
          metadata: {'todo.checked': false},
          updatedAt: now,
        ),
      RecordType.heading => record.copyWith(
          type: RecordType.heading,
          metadata: {'heading.level': 1},
          updatedAt: now,
        ),
      RecordType.bulletList => record.copyWith(
          type: RecordType.bulletList,
          metadata: {'bulletList.indentLevel': 0},
          updatedAt: now,
        ),
      RecordType.habit => record.copyWith(
          type: RecordType.habit,
          content: '',
          metadata: {
            'habit.name': record.content,
            'habit.completions': <String>[],
            'habit.frequency': 'daily',
            'habit.archived': false,
          },
          updatedAt: now,
        ),
    };
  }

  // M5: Identify conversions that silently lose user data so we can offer undo.
  // - Habit → anything: loses completion history and streak.
  // - Anything → Habit: clears content field (moves to habit.name metadata).
  // - Checked todo → non-todo: loses the checked state.
  bool _isLossyConversion(RecordType from, RecordType to) {
    if (from == RecordType.habit) return true;
    if (to == RecordType.habit) return true;
    if (from == RecordType.todo && to != RecordType.todo && record.isChecked) {
      return true;
    }
    return false;
  }

  String _typeName(RecordType type) => switch (type) {
        RecordType.text => 'text',
        RecordType.todo => 'todo',
        RecordType.heading => 'heading',
        RecordType.bulletList => 'bullet',
        RecordType.habit => 'habit',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // M2: 44×44 touch target (was 30×28). The larger tap area extends into the
    // content padding zone but only the icon is visible — same visual footprint.
    // See: https://m3.material.io/foundations/interaction/states/overview
    return SizedBox(
      width: GridConstants.minTouchTarget,
      height: GridConstants.minTouchTarget,
      child: Center(
        child: PopupMenuButton<RecordType>(
          tooltip: 'Change record type',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          // M2: Bump icon to 18px and use onSurfaceVariant (slightly more visible
          // than outline) so the button is easier to discover.
          icon: Icon(
            Icons.add,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          iconSize: 18,
          itemBuilder: (context) => [
            // P3: Fixed-width SizedBox for the glyph slot — prevents alignment
            // from depending on font-specific Unicode character widths.
            PopupMenuItem(
              value: RecordType.text,
              child: _MenuRow(glyph: 'T', label: 'Text'),
            ),
            PopupMenuItem(
              value: RecordType.todo,
              child: _MenuRow(glyph: '☐', label: 'Todo'),
            ),
            PopupMenuItem(
              value: RecordType.heading,
              child: _MenuRow(glyph: 'H1', label: 'Heading'),
            ),
            PopupMenuItem(
              value: RecordType.bulletList,
              child: _MenuRow(glyph: '•', label: 'Bullet'),
            ),
            PopupMenuItem(
              value: RecordType.habit,
              child: _MenuRow(glyph: '○', label: 'Habit'),
            ),
          ],
          onSelected: (type) {
            if (type == record.type) return;

            final original = record;
            final converted = _convertTo(type);
            onSave(converted);
            RefocusRecordNotification(recordId: record.id).dispatch(context);

            // M5: Offer undo via SnackBar for conversions that lose data,
            // matching the empty-record deletion undo pattern.
            if (_isLossyConversion(original.type, type)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Converted to ${_typeName(type)} — some data may be lost',
                  ),
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => onSave(original),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// P3: Consistent menu-item layout using a Row with a fixed-width glyph container.
// Avoids relying on Unicode character widths for column alignment.
class _MenuRow extends StatelessWidget {
  final String glyph;
  final String label;

  const _MenuRow({required this.glyph, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(glyph, textAlign: TextAlign.center),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
