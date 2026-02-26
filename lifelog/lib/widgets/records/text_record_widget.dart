import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../constants/grid_constants.dart';
import '../../notifications/navigation_notifications.dart';
import 'record_text_field.dart';

// ============================================================================
// SHARED HELPERS — used by all record-type widgets for type conversion
// ============================================================================

/// Converts [record] to [targetType], preserving content where meaningful.
///
/// Habit is the exception: content becomes the habit name (stored in metadata)
/// because habit records use content: '' and store display text in metadata.
Record convertRecordType(Record record, RecordType targetType) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return switch (targetType) {
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

/// Shows the record-type picker menu anchored to [gutterContext]'s render box.
///
/// Uses [showMenu] (imperative) rather than [PopupMenuButton] (declarative)
/// because the gutter widgets for todo/bullet/habit already own their tap
/// gesture for existing functionality (checkbox toggle, habit completion).
/// Long-pressing opens this menu; tapping still performs the original action.
/// See: https://api.flutter.dev/flutter/material/showMenu.html
Future<void> showRecordTypePicker({
  required BuildContext gutterContext,
  required RecordType currentType,
  required void Function(RecordType) onSelected,
}) async {
  final renderBox = gutterContext.findRenderObject()! as RenderBox;
  final overlay =
      Overlay.of(gutterContext).context.findRenderObject()! as RenderBox;
  // RelativeRect positions the menu relative to the overlay (full-screen).
  // fromRect maps the gutter widget's screen rect into overlay coordinates.
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero, ancestor: overlay),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  final selected = await showMenu<RecordType>(
    context: gutterContext,
    position: position,
    items: const [
      PopupMenuItem(value: RecordType.text, child: Text('T   Text')),
      PopupMenuItem(value: RecordType.todo, child: Text('☐   Todo')),
      PopupMenuItem(value: RecordType.heading, child: Text('H1  Heading')),
      PopupMenuItem(value: RecordType.bulletList, child: Text('•   Bullet')),
      PopupMenuItem(value: RecordType.habit, child: Text('○   Habit')),
    ],
  );

  if (selected != null && selected != currentType) {
    onSelected(selected);
  }
}

// ============================================================================
// TEXT RECORD WIDGET
// ============================================================================

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
/// Now public (`TypePickerButton`, not `_TypePickerButton`) so heading,
/// todo, bullet, and habit widgets can reuse it for the same picker UX.
/// Uses [PopupMenuButton] — a Material widget that manages its own overlay
/// state, so no StatefulWidget is needed here.
/// See: https://api.flutter.dev/flutter/material/PopupMenuButton-class.html
class TypePickerButton extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;

  const TypePickerButton({super.key, required this.record, required this.onSave});

  Record _convertTo(RecordType type) => convertRecordType(record, type);

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
          // Constrain button to fit the gutter — overrides Material's 48px minimum
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.add,
            size: 14,
            // outline color keeps it muted against the paper background
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
            // Mirrors the slash-command refocus pattern: dispatch the notification
            // synchronously (before the rebuild) so RecordSection's listener can
            // addPostFrameCallback. After the rebuild the new FocusNode is
            // registered, and the callback fires to restore keyboard focus.
            RefocusRecordNotification(recordId: record.id).dispatch(context);
          },
        ),
      ),
    );
  }
}
