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
/// This is the main entry point for rendering any record in the journal.
/// It handles the shared layout (padding, grid alignment) and delegates
/// type-specific rendering to sub-widgets.
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

  const AdaptiveRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPadding =
            GridConstants.calculateContentLeftPadding(constraints.maxWidth);
        final rightPadding =
            GridConstants.calculateContentRightPadding(constraints.maxWidth);

        // Minimum height: all records are at least one grid row (24px).
        // ConstrainedBox vs SizedBox: SizedBox clips multi-line text; ConstrainedBox
        // sets a floor while allowing the widget to expand.
        const minHeight = GridConstants.spacing;

        return Padding(
          padding: EdgeInsets.only(
            left: leftPadding,
            right: rightPadding,
            top: GridConstants.itemVerticalSpacing,
            bottom: GridConstants.itemVerticalSpacing,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            // Exhaustive switch: compiler enforces all RecordType cases are handled
            child: switch (record.type) {
              RecordType.text => TextRecordWidget(
                  record: record,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  recordIndex: recordIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              RecordType.heading => HeadingRecordWidget(
                  record: record,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  recordIndex: recordIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              RecordType.todo => TodoRecordWidget(
                  record: record,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  recordIndex: recordIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              RecordType.bulletList => BulletListRecordWidget(
                  record: record,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  recordIndex: recordIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              RecordType.habit => HabitRecordWidget(
                  record: record,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  recordIndex: recordIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
            },
          ),
        );
      },
    );
  }
}
