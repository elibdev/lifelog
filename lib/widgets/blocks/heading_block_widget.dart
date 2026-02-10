import 'package:flutter/material.dart';
import '../../models/block.dart';
import '../../constants/grid_constants.dart';
import 'block_text_field.dart';

/// Renders a heading block with configurable level (1, 2, or 3).
///
/// Heading heights are multiples of the 24px grid:
/// - H1: 48px (bold, large)
/// - H2: 24px (bold, medium)
/// - H3: 24px (bold, normal size)
///
/// No leading widget (checkbox/bullet) — headings use full width.
class HeadingBlockWidget extends StatelessWidget {
  final Block block;
  final Function(Block) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? blockIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const HeadingBlockWidget({
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
    final level = block.headingLevel.clamp(1, 3);
    final theme = Theme.of(context).textTheme;

    // Map heading level to TextStyle
    // H1 uses a taller line height to span 2 grid rows (48px)
    final TextStyle style;
    switch (level) {
      case 1:
        style = (theme.headlineSmall ?? theme.titleLarge!).copyWith(
          fontWeight: FontWeight.bold,
          // 48px total height / ~24px font = ~2.0 line height multiplier
          height: 2.0,
        );
        break;
      case 2:
        style = (theme.titleLarge ?? theme.titleMedium!).copyWith(
          fontWeight: FontWeight.bold,
          height: GridConstants.textLineHeightMultiplier,
        );
        break;
      default:
        style = (theme.titleMedium ?? theme.bodyLarge!).copyWith(
          fontWeight: FontWeight.bold,
          height: GridConstants.textLineHeightMultiplier,
        );
    }

    return BlockTextField(
      block: block,
      onSave: onSave,
      onDelete: onDelete,
      onSubmitted: onSubmitted,
      blockIndex: blockIndex,
      onFocusNodeCreated: onFocusNodeCreated,
      onFocusNodeDisposed: onFocusNodeDisposed,
      textStyle: style,
    );
  }
}
