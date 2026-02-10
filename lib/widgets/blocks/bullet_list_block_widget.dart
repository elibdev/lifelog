import 'package:flutter/material.dart';
import '../../models/block.dart';
import '../../constants/grid_constants.dart';
import 'block_text_field.dart';

/// Renders a bulleted list item with indent support.
///
/// Indent level controls left padding: each level adds one grid spacing (24px).
/// The bullet character changes by level for visual hierarchy.
class BulletListBlockWidget extends StatelessWidget {
  final Block block;
  final Function(Block) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? blockIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const BulletListBlockWidget({
    super.key,
    required this.block,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.blockIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  /// Different bullet characters per indent level for visual hierarchy
  String _bulletForLevel(int level) {
    const bullets = ['•', '◦', '▪'];
    return bullets[level.clamp(0, bullets.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final indentLevel = block.indentLevel;

    return Padding(
      // Each indent level shifts content right by one grid column
      padding: EdgeInsets.only(
        left: indentLevel * GridConstants.spacing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet leading widget
          Padding(
            padding:
                const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
            child: SizedBox(
              width: GridConstants.checkboxSize,
              height: GridConstants.checkboxSize,
              child: Center(child: Text(_bulletForLevel(indentLevel))),
            ),
          ),
          // Text field
          Expanded(
            child: BlockTextField(
              block: block,
              onSave: onSave,
              onDelete: onDelete,
              onSubmitted: onSubmitted,
              blockIndex: blockIndex,
              onFocusNodeCreated: onFocusNodeCreated,
              onFocusNodeDisposed: onFocusNodeDisposed,
            ),
          ),
        ],
      ),
    );
  }
}
