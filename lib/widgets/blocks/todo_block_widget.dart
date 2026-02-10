import 'package:flutter/material.dart';
import '../../models/block.dart';
import '../../constants/grid_constants.dart';
import 'block_text_field.dart';

/// Renders a todo block with a checkbox and optional strikethrough text.
/// Equivalent to the old TodoRecord rendering.
class TodoBlockWidget extends StatelessWidget {
  final Block block;
  final Function(Block) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? blockIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const TodoBlockWidget({
    super.key,
    required this.block,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.blockIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  void _handleCheckboxToggle(bool? value) {
    if (value == null) return;
    final updated = block.copyWithMetadata({'checked': value});
    onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = block.isChecked;
    final isEmpty = block.content.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox leading widget
        Padding(
          padding: const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
          child: SizedBox(
            width: GridConstants.checkboxSize,
            height: GridConstants.checkboxSize,
            child: Checkbox(
              value: isChecked,
              onChanged: isEmpty ? null : _handleCheckboxToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        // Text field with strikethrough when checked
        Expanded(
          child: BlockTextField(
            block: block,
            onSave: onSave,
            onDelete: onDelete,
            onSubmitted: onSubmitted,
            blockIndex: blockIndex,
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
