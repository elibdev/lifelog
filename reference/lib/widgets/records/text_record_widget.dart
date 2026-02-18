import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a plain text record with a bullet point leading widget.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          child: SizedBox(
            width: GridConstants.checkboxSize,
            // textAlign centers the bullet within the fixed-width column without
            // using Center, which would expand vertically and misalign on multi-line text.
            child: const Text('•', textAlign: TextAlign.center),
          ),
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
          ),
        ),
      ],
    );
  }
}
