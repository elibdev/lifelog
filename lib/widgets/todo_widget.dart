import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/journal_record.dart';

class TodoWidget extends StatefulWidget {
  final JournalRecord record;
  final Function(Map<String, dynamic>) onUpdate;
  final VoidCallback? onDelete;

  const TodoWidget({
    super.key,
    required this.record,
    required this.onUpdate,
    this.onDelete,
  });

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final content = widget.record.metadata['content'] ?? '';
    _controller = TextEditingController(text: content);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    // Debounced save (500ms)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onUpdate({'content': text});
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Handle Backspace at beginning - delete empty todo
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.text.isEmpty && widget.onDelete != null) {
          widget.onDelete!();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.record.metadata['checked'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          SizedBox(
            width: 16,
            height: 16,
            child: Transform.translate(
              offset: const Offset(0, 3),
              child: Checkbox(
                value: checked,
                onChanged: (val) => widget.onUpdate({'checked': val ?? false}),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Text field
          Expanded(
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onTextChanged,
                maxLines: null,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
