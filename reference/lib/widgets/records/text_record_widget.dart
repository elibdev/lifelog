import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../notifications/navigation_notifications.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a plain text record.
///
/// No leading indicator — text sits flush with the content column,
/// aligned with the text of other record types via a reserved gutter.
/// In editable mode the gutter holds a type-picker button (C1: second entry
/// point for record types, complementing slash commands for touch/pointer users).
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // C1: type-picker in the gutter — touch/pointer alternative to slash cmds.
        // Hidden in readOnly (search results) where conversion makes no sense.
        if (!readOnly)
          TypePickerButton(record: record, onSave: onSave)
        else
          const SizedBox(
            width: GridConstants.checkboxSize + GridConstants.checkboxToTextGap,
          ),
        Expanded(
          child: RecordTextField(
            record: record,
            onSave: onSave,
            onDelete: onDelete,
            onSubmitted: onSubmitted,
            recordIndex: recordIndex,
            onFocusNodeCreated: onFocusNodeCreated,
            onFocusNodeDisposed: onFocusNodeDisposed,
            readOnly: readOnly,
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: GridConstants.checkboxSize + GridConstants.checkboxToTextGap,
      height: GridConstants.rowHeight,
      child: Center(
        child: PopupMenuButton<RecordType>(
          tooltip: 'Change record type',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.add,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          iconSize: 14,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: RecordType.text,
              child: Text('T   Text'),
            ),
            const PopupMenuItem(
              value: RecordType.todo,
              child: Text('☐   Todo'),
            ),
            const PopupMenuItem(
              value: RecordType.heading,
              child: Text('H1  Heading'),
            ),
            const PopupMenuItem(
              value: RecordType.bulletList,
              child: Text('•   Bullet'),
            ),
            const PopupMenuItem(
              value: RecordType.habit,
              child: Text('○   Habit'),
            ),
          ],
          onSelected: (type) {
            if (type == record.type) return;
            onSave(_convertTo(type));
            RefocusRecordNotification(recordId: record.id).dispatch(context);
          },
        ),
      ),
    );
  }
}
