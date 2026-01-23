import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/record.dart';

class RecordWidget extends StatefulWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)?
  onSubmitted; // Called when user presses Enter, passes record ID
  final bool autofocus; // Auto-focus this field

  const RecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  State<RecordWidget> createState() => _RecordWidgetState();
}

class _RecordWidgetState extends State<RecordWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.record.content);
    _focusNode = FocusNode();

    // Listen for focus changes - rebuild for visual feedback AND delete empty records
    _focusNode.addListener(_handleFocusChange);

    // Auto-focus if requested
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _handleFocusChange() {
    // Rebuild widget on focus change
    if (mounted) setState(() {});

    // When focus is lost, delete if content is empty/whitespace
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onDelete(widget.record.id);
    }
  }

  @override
  void didUpdateWidget(RecordWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the record ID changed, update the controller
    if (widget.record.id != oldWidget.record.id) {
      _controller.text = widget.record.content;
    }
    // If content changed externally, update controller
    else if (widget.record.content != oldWidget.record.content &&
        widget.record.content != _controller.text) {
      _controller.text = widget.record.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;

    // Save immediately (no debouncing at widget level - parent handles it)
    // Note: We no longer delete immediately when empty - deletion happens on focus loss or delete key
    if (text != widget.record.content) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updatedRecord = widget.record.copyWith(
        content: text,
        updatedAt: now,
      );
      widget.onSave(updatedRecord);
    }
  }

  void _handleCheckboxToggle(bool? value) {
    if (widget.record is! TodoRecord) return;
    final todo = widget.record as TodoRecord;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = todo.copyWithChecked(
      checked: value ?? false,
      updatedAt: now,
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final isEmpty = record.content.isEmpty;
    final isChecked = record is TodoRecord && record.checked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0), // Reduced from 4.0 for compactness
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading widget (polymorphic!) - checkbox or bullet
          // No top padding - aligns with first line of text
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: record is TodoRecord
                  // ExcludeFocus removes checkbox from tab order - keeps focus flow clean
                  ? ExcludeFocus(
                      child: Checkbox(
                        value: record.checked,
                        onChanged: isEmpty ? null : _handleCheckboxToggle,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : const Center(
                      // Simple bullet point for notes
                      child: Text('•'),
                    ),
            ),
          ),
          // Text field
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  // Ctrl/Cmd+Enter = Toggle checkbox (for todos)
                  if (event.logicalKey == LogicalKeyboardKey.enter &&
                      (HardwareKeyboard.instance.isControlPressed ||
                          HardwareKeyboard.instance.isMetaPressed) &&
                      record is TodoRecord &&
                      !isEmpty) {
                    _handleCheckboxToggle(!record.checked);
                    return KeyEventResult.handled;
                  }
                  // Delete/backspace at beginning of empty record = delete record
                  // This allows users to delete empty records by pressing backspace/delete
                  else if ((event.logicalKey == LogicalKeyboardKey.backspace ||
                          event.logicalKey == LogicalKeyboardKey.delete) &&
                      _controller.text.trim().isEmpty &&
                      _controller.selection.start == 0) {
                    widget.onDelete(widget.record.id);
                    return KeyEventResult.handled;
                  }
                  // Arrow down = Tab (focus next)
                  else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    FocusScope.of(context).nextFocus();
                    return KeyEventResult.handled;
                  }
                  // Arrow up = Shift+Tab (focus previous)
                  else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    FocusScope.of(context).previousFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                // Strikethrough for completed todos - uses default Material styling
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  _handleTextChange();
                  setState(() {});
                },
                onSubmitted: (_) {
                  // Save current text immediately
                  if (_controller.text.isNotEmpty &&
                      _controller.text != widget.record.content) {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final updatedRecord = widget.record.copyWith(
                      content: _controller.text,
                      updatedAt: now,
                    );
                    widget.onSave(updatedRecord);
                  }
                  // Notify parent which record triggered Enter
                  widget.onSubmitted?.call(widget.record.id);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
