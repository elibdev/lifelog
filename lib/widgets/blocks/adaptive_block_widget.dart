import 'package:flutter/material.dart';
import '../../models/block.dart';
import '../../constants/grid_constants.dart';
import 'text_block_widget.dart';
import 'heading_block_widget.dart';
import 'todo_block_widget.dart';
import 'bullet_list_block_widget.dart';
import 'habit_block_widget.dart';

/// Routes a Block to the appropriate sub-widget based on its type.
///
/// This is the main entry point for rendering any block in the journal.
/// It handles the shared layout (padding, grid alignment) and delegates
/// type-specific rendering to sub-widgets.
///
/// Dart's exhaustive switch expression ensures a compile-time error if
/// a new BlockType is added without a corresponding widget.
/// See: https://dart.dev/language/branches#switch-expressions
class AdaptiveBlockWidget extends StatelessWidget {
  final Block block;
  final Function(Block) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? blockIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const AdaptiveBlockWidget({
    super.key,
    required this.block,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.blockIndex,
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

        // H1 headings span 2 grid rows (48px), everything else is 1 row (24px)
        final height = (block.type == BlockType.heading && block.headingLevel == 1)
            ? GridConstants.spacing * 2
            : GridConstants.spacing;

        return Padding(
          padding: EdgeInsets.only(
            left: leftPadding,
            right: rightPadding,
            top: GridConstants.itemVerticalSpacing,
            bottom: GridConstants.itemVerticalSpacing,
          ),
          child: SizedBox(
            height: height,
            // Exhaustive switch: compiler enforces all BlockType cases are handled
            child: switch (block.type) {
              BlockType.text => TextBlockWidget(
                  block: block,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  blockIndex: blockIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              BlockType.heading => HeadingBlockWidget(
                  block: block,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  blockIndex: blockIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              BlockType.todo => TodoBlockWidget(
                  block: block,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  blockIndex: blockIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              BlockType.bulletList => BulletListBlockWidget(
                  block: block,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  blockIndex: blockIndex,
                  onFocusNodeCreated: onFocusNodeCreated,
                  onFocusNodeDisposed: onFocusNodeDisposed,
                ),
              BlockType.habit => HabitBlockWidget(
                  block: block,
                  onSave: onSave,
                  onDelete: onDelete,
                  onSubmitted: onSubmitted,
                  blockIndex: blockIndex,
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
