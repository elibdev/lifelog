import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/record.dart';

class RecordWidget extends StatefulWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted; // Called when user presses Enter, passes record ID
  final VoidCallback? onNavigateUp; // Called when user presses arrow up
  final VoidCallback? onNavigateDown; // Called when user presses arrow down
  final bool autofocus; // Auto-focus this field

  const RecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.onNavigateUp,
    this.onNavigateDown,
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

    // Rebuild when focus changes to show/hide focus background
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // Auto-focus if requested
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
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

  void requestFocus() {
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;

    // Delete when content is empty/whitespace - immediately triggers deletion
    if (text.trim().isEmpty) {
      widget.onDelete(widget.record.id);
      return;
    }

    // Save immediately (no debouncing at widget level - parent handles it)
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading widget (polymorphic!) - checkbox or bullet
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: record is TodoRecord
                    // ExcludeFocus removes checkbox from tab order - keeps focus flow clean
                    ? ExcludeFocus(
                        child: Transform.scale(
                          scale: 1.1, // Slightly larger for easier clicking
                          child: Checkbox(
                            value: record.checked,
                            onChanged: isEmpty ? null : _handleCheckboxToggle,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            // Smooth animation when checking/unchecking
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        // More refined bullet point
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
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
                        (event.isControlPressed || event.isMetaPressed) &&
                        record is TodoRecord &&
                        !isEmpty) {
                      _handleCheckboxToggle(!(record as TodoRecord).checked);
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
                child: AnimatedContainer(
                  // Smooth transition when focus changes (200ms animation)
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  // Subtle background on focus for better feedback
                  decoration: _focusNode.hasFocus && !isEmpty
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  padding: _focusNode.hasFocus && !isEmpty
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : EdgeInsets.zero,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      // Subtle hint for empty fields
                      hintText: isEmpty ? (record is TodoRecord ? 'Add a task...' : 'Add a note...') : null,
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    // Strikethrough for completed todos - satisfying visual feedback!
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      color: isChecked
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                          : null,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      _handleTextChange();
                      // Rebuild to update focus background
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      // Save current text immediately
                      if (_controller.text.isNotEmpty && _controller.text != widget.record.content) {
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
            ),
          ],
        ),
    );
  }
}
