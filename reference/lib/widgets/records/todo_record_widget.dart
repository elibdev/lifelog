import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a todo record with a checkbox and optional strikethrough text.
class TodoRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const TodoRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  void _handleCheckboxToggle(bool? value) {
    if (value == null) return;
    // Namespaced metadata key: "todo.checked"
    final updated = record.copyWithMetadata({'todo.checked': value});
    onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = record.isChecked;
    final isEmpty = record.content.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          child: SizedBox(
            width: GridConstants.checkboxSize,
            child: Checkbox(
              value: isChecked,
              onChanged: isEmpty ? null : _handleCheckboxToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
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
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  height: GridConstants.textLineHeightMultiplier,
                ),
            onToggleCheckbox: (value) => _handleCheckboxToggle(value),
          ),
        ),
      ],
    );
  }
}
