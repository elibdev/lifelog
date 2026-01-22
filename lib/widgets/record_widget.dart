import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/record.dart';
import '../utils/debouncer.dart';

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
  late Debouncer _debouncer;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.record.content);
    _debouncer = Debouncer();
    _focusNode = FocusNode();

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
    _debouncer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;

    // Delete immediately when content is cleared (no debounce)
    if (text.isEmpty && widget.record.content.isNotEmpty) {
      widget.onDelete(widget.record.id);
      return;
    }

    // Debounce saves
    _debouncer.call(() {
      if (!mounted) return;

      if (text != widget.record.content && text.isNotEmpty) {
        // Content changed - save record
        final now = DateTime.now().millisecondsSinceEpoch;
        final updatedRecord = widget.record.copyWith(
          content: text,
          updatedAt: now,
        );
        widget.onSave(updatedRecord);
      }
    });
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

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading widget (polymorphic!)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, right: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: record is TodoRecord
                    ? GestureDetector(
                        onTap: isEmpty ? null : () => _handleCheckboxToggle(!record.checked),
                        child: Checkbox(
                          value: record.checked,
                          onChanged: isEmpty ? null : _handleCheckboxToggle,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    : Center(
                        child: Icon(Icons.circle, size: 6, color: Colors.grey[700]),
                      ),
              ),
            ),
            // Text field
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    // Arrow down = Tab (focus next)
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
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
                  style: const TextStyle(height: 1.3),
                  maxLines: null,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _handleTextChange(),
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
          ],
        ),
    );
  }
}
