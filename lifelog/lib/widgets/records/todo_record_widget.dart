import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a todo record with a refined checkbox and optional strikethrough.
///
/// Checked todos get reduced opacity and strikethrough — they recede
/// visually, letting unchecked items stand out. The checkbox uses the
/// theme's CheckboxThemeData for consistent styling.
class TodoRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;
  final bool readOnly;

  const TodoRecordWidget({
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

  void _handleCheckboxToggle(bool? value) {
    if (value == null) return;
    final updated = record.copyWithMetadata({'todo.checked': value});
    onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChecked = record.isChecked;
    final isEmpty = record.content.isEmpty;

    return Opacity(
      // Checked items fade to signal completion without disappearing
      opacity: isChecked ? 0.5 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
            child: SizedBox(
              width: GridConstants.checkboxSize,
              height: GridConstants.rowHeight,
              child: Center(
                child: SizedBox(
                  width: GridConstants.checkboxSize,
                  height: GridConstants.checkboxSize,
                  child: Checkbox(
                    value: isChecked,
                    // C2: also disable in readOnly (search results)
                    onChanged: (isEmpty || readOnly) ? null : _handleCheckboxToggle,
                  ),
                ),
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
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                decoration: isChecked ? TextDecoration.lineThrough : null,
                // Strikethrough color matches the muted text
                decorationColor: theme.colorScheme.outline,
                height: GridConstants.textLineHeightMultiplier,
              ),
              onToggleCheckbox: (value) => _handleCheckboxToggle(value),
              readOnly: readOnly,
            ),
          ),
        ],
      ),
    );
  }
}
