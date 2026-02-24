import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'record_text_field.dart';

/// Renders a plain text record.
///
/// No leading indicator and no gutter — text sits flush at the left margin,
/// visually expressing "prose entry" vs a list item (bullet/todo).
class TextRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const TextRecordWidget({
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
    return RecordTextField(
      record: record,
      onSave: onSave,
      onDelete: onDelete,
      onSubmitted: onSubmitted,
      recordIndex: recordIndex,
      onFocusNodeCreated: onFocusNodeCreated,
      onFocusNodeDisposed: onFocusNodeDisposed,
    );
  }
}
