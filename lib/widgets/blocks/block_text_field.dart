import 'package:flutter/material.dart';
import '../../models/block.dart';
import '../../services/keyboard_service.dart';
import '../../constants/grid_constants.dart';

/// Shared text editing widget extracted from the old RecordWidget.
///
/// Encapsulates: TextEditingController, FocusNode lifecycle, keyboard shortcuts,
/// and text change handling. Each block sub-widget composes this with its own
/// leading widget (checkbox, bullet, etc.).
///
/// This follows Flutter's "composition over inheritance" philosophy:
/// instead of a base class with overrides, each block type wraps BlockTextField
/// inside its own layout.
/// See: https://docs.flutter.dev/resources/architectural-overview#composition
class BlockTextField extends StatefulWidget {
  final Block block;
  final Function(Block) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? blockIndex;
  final void Function(int index, String blockId, FocusNode node)?
      onFocusNodeCreated;
  final void Function(String blockId)? onFocusNodeDisposed;

  /// Optional text style override (used by headings for larger text)
  final TextStyle? textStyle;

  /// Optional callback for checkbox toggle (used by todo blocks)
  final Function(bool)? onToggleCheckbox;

  const BlockTextField({
    super.key,
    required this.block,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.blockIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
    this.textStyle,
    this.onToggleCheckbox,
  });

  @override
  State<BlockTextField> createState() => BlockTextFieldState();
}

class BlockTextFieldState extends State<BlockTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  /// Expose focus node so parent widgets can request focus
  FocusNode get focusNode => _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.content);
    _setupFocusNode();
  }

  void _setupFocusNode() {
    _focusNode = FocusNode();
    widget.onFocusNodeCreated?.call(
      widget.blockIndex ?? -1,
      widget.block.id,
      _focusNode,
    );
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onDelete(widget.block.id);
    }
  }

  @override
  void didUpdateWidget(BlockTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.id != oldWidget.block.id) {
      _controller.text = widget.block.content;
    } else if (widget.block.content != oldWidget.block.content &&
        widget.block.content != _controller.text) {
      _controller.text = widget.block.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _teardownFocusNode();
    super.dispose();
  }

  void _teardownFocusNode() {
    _focusNode.removeListener(_handleFocusChange);
    widget.onFocusNodeDisposed?.call(widget.block.id);
    _focusNode.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;
    if (text != widget.block.content) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = widget.block.copyWith(content: text, updatedAt: now);
      widget.onSave(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: GridConstants.textLineHeightMultiplier,
        );
    final effectiveStyle = widget.textStyle ?? defaultStyle;

    // Focus + keyboard handler wrapping the TextField
    // KeyboardService handles arrow navigation and action keys
    return Focus(
      onKeyEvent: (node, event) {
        return KeyboardService.handleBlockKeyEvent(
          event: event,
          node: node,
          block: widget.block,
          blockIndex: widget.blockIndex ?? -1,
          textController: _controller,
          context: context,
          onDelete: widget.onDelete,
          onToggleCheckbox: widget.onToggleCheckbox ?? (_) {},
        );
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: effectiveStyle,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _handleTextChange(),
        onSubmitted: (_) {
          if (_controller.text.isNotEmpty &&
              _controller.text != widget.block.content) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final updated =
                widget.block.copyWith(content: _controller.text, updatedAt: now);
            widget.onSave(updated);
          }
          widget.onSubmitted?.call(widget.block.id);
        },
      ),
    );
  }
}
