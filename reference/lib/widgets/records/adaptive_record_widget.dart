import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'text_record_widget.dart';
import 'heading_record_widget.dart';
import 'todo_record_widget.dart';
import 'bullet_list_record_widget.dart';
import 'habit_record_widget.dart';

/// Routes a Record to the appropriate sub-widget based on its type.
///
/// Owns the shared layout for every record: responsive padding, minimum row
/// height, and the leading TypePickerButton gutter. Sub-widgets only need to
/// render their type-specific indicator (checkbox, bullet, circle) + content.
///
/// Dart's exhaustive switch expression ensures a compile-time error if
/// a new RecordType is added without a corresponding widget.
/// See: https://dart.dev/language/branches#switch-expressions
class AdaptiveRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;
  // C2: when true, all sub-widgets render as read-only (used in search results)
  final bool readOnly;

  const AdaptiveRecordWidget({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPadding =
            GridConstants.calculateContentLeftPadding(constraints.maxWidth);
        final rightPadding =
            GridConstants.calculateContentRightPadding(constraints.maxWidth);

        return Padding(
          padding: EdgeInsets.only(
            left: leftPadding,
            right: rightPadding,
            top: GridConstants.itemVerticalSpacing,
            bottom: GridConstants.itemVerticalSpacing,
          ),
          // ConstrainedBox vs SizedBox: SizedBox clips multi-line text; ConstrainedBox
          // sets a floor while allowing the widget to expand.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GridConstants.rowHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // C1: type-picker centralised here so individual widgets stay
                // focused on their own indicator without TypePickerButton boilerplate.
                // Hidden in readOnly (search results) where conversion makes no sense.
                if (!readOnly)
                  TypePickerButton(record: record, onSave: onSave)
                else
                  const SizedBox(
                    width: GridConstants.checkboxSize + GridConstants.checkboxToTextGap,
                  ),
                // Exhaustive switch: compiler enforces all RecordType cases are handled
                Expanded(
                  child: switch (record.type) {
                    RecordType.text => TextRecordWidget(
                        record: record,
                        onSave: onSave,
                        onDelete: onDelete,
                        onSubmitted: onSubmitted,
                        recordIndex: recordIndex,
                        onFocusNodeCreated: onFocusNodeCreated,
                        onFocusNodeDisposed: onFocusNodeDisposed,
                        readOnly: readOnly,
                      ),
                    RecordType.heading => HeadingRecordWidget(
                        record: record,
                        onSave: onSave,
                        onDelete: onDelete,
                        onSubmitted: onSubmitted,
                        recordIndex: recordIndex,
                        onFocusNodeCreated: onFocusNodeCreated,
                        onFocusNodeDisposed: onFocusNodeDisposed,
                        readOnly: readOnly,
                      ),
                    RecordType.todo => TodoRecordWidget(
                        record: record,
                        onSave: onSave,
                        onDelete: onDelete,
                        onSubmitted: onSubmitted,
                        recordIndex: recordIndex,
                        onFocusNodeCreated: onFocusNodeCreated,
                        onFocusNodeDisposed: onFocusNodeDisposed,
                        readOnly: readOnly,
                      ),
                    RecordType.bulletList => BulletListRecordWidget(
                        record: record,
                        onSave: onSave,
                        onDelete: onDelete,
                        onSubmitted: onSubmitted,
                        recordIndex: recordIndex,
                        onFocusNodeCreated: onFocusNodeCreated,
                        onFocusNodeDisposed: onFocusNodeDisposed,
                        readOnly: readOnly,
                      ),
                    RecordType.habit => HabitRecordWidget(
                        record: record,
                        onSave: onSave,
                        onDelete: onDelete,
                        onSubmitted: onSubmitted,
                        recordIndex: recordIndex,
                        onFocusNodeCreated: onFocusNodeCreated,
                        onFocusNodeDisposed: onFocusNodeDisposed,
                        readOnly: readOnly,
                      ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
