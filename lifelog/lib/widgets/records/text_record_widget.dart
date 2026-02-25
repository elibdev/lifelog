import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a plain text record.
///
/// No leading indicator — text sits flush with the content column,
/// aligned with the text of other record types via a reserved gutter.
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
