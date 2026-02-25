import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../services/keyboard_service.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';

/// Shared text editing widget used by all record sub-widgets.
///
/// Encapsulates: TextEditingController, FocusNode lifecycle, keyboard shortcuts,
/// and text change handling. Each record sub-widget composes this with its own
/// leading widget (checkbox, bullet, etc.).
///
/// This follows Flutter's "composition over inheritance" philosophy:
/// instead of a base class with overrides, each record type wraps RecordTextField
/// inside its own layout.
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

  /// Optional text style override (used by headings for larger text)
  final TextStyle? textStyle;

  /// Optional callback for checkbox toggle (used by todo records)
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
    final defaultStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          border: InputBorder.none,
          // Flutter resolves enabledBorder/focusedBorder before border — override
          // all states so the theme's OutlineInputBorder never shows on record rows.
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: effectiveStyle,
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
