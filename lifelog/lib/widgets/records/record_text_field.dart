import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../services/keyboard_service.dart';
import '../../constants/grid_constants.dart';

/// Shared text editing widget used by all record sub-widgets.
///
/// Each record type composes this with its own leading widget (checkbox,
/// bullet, etc.) — Flutter's "composition over inheritance" pattern.
/// See: https://docs.flutter.dev/resources/architectural-overview#composition
class RecordTextField extends StatefulWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int index, String recordId, FocusNode node)?
      onFocusNodeCreated;
  final void Function(String recordId)? onFocusNodeDisposed;
  final TextStyle? textStyle;
  final Function(bool)? onToggleCheckbox;

  const RecordTextField({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
    this.textStyle,
    this.onToggleCheckbox,
  });

  @override
  State<RecordTextField> createState() => RecordTextFieldState();
}

class RecordTextFieldState extends State<RecordTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  FocusNode get focusNode => _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.record.content);
    _setupFocusNode();
  }

  void _setupFocusNode() {
    _focusNode = FocusNode();
    widget.onFocusNodeCreated?.call(
      widget.recordIndex ?? -1,
      widget.record.id,
      _focusNode,
    );
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onDelete(widget.record.id);
    }
  }

  @override
  void didUpdateWidget(RecordTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.id != oldWidget.record.id) {
      _controller.text = widget.record.content;
    } else if (widget.record.content != oldWidget.record.content &&
        widget.record.content != _controller.text) {
      _controller.text = widget.record.content;
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
    widget.onFocusNodeDisposed?.call(widget.record.id);
    _focusNode.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;
    if (text != widget.record.content) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = widget.record.copyWith(content: text, updatedAt: now);
      widget.onSave(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Default style uses the design system's body text
    final defaultStyle = theme.textTheme.bodyMedium?.copyWith(
      height: GridConstants.textLineHeightMultiplier,
    );
    final effectiveStyle = widget.textStyle ?? defaultStyle;

    return Focus(
      onKeyEvent: (node, event) {
        return KeyboardService.handleRecordKeyEvent(
          event: event,
          node: node,
          record: widget.record,
          recordIndex: widget.recordIndex ?? -1,
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
          // Borderless — text sits directly on the page like a notebook
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
        style: effectiveStyle,
        // Allows cursor color to follow the accent
        cursorColor: theme.colorScheme.primary,
        cursorWidth: 1.5,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _handleTextChange(),
        onSubmitted: (_) {
          if (_controller.text.isNotEmpty &&
              _controller.text != widget.record.content) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final updated = widget.record
                .copyWith(content: _controller.text, updatedAt: now);
            widget.onSave(updated);
          }
          widget.onSubmitted?.call(widget.record.id);
        },
      ),
    );
  }
}
