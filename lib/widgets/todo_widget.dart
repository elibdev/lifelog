import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/journal_record.dart';

class TodoWidget extends StatefulWidget {
  final JournalRecord? record; // null if ephemeral
  final bool isEmpty;
  final Function(Map<String, dynamic>)? onUpdate;
  final Function(String)? onCreate;
  final VoidCallback? onDelete;

  const TodoWidget({
    super.key,
    this.record,
    this.isEmpty = false,
    this.onUpdate,
    this.onCreate,
    this.onDelete,
  });

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounce;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    final content = widget.record?.metadata['content'] ?? '';
    _controller = TextEditingController(text: content);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
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
      _saveNow(text);
    });
  }

  void _saveNow(String text) {
    if (widget.record != null && widget.onUpdate != null) {
      // Update existing record
      widget.onUpdate!({'content': text});
    } else if (text.isNotEmpty && widget.onCreate != null) {
      // Create new record from ephemeral
      widget.onCreate!(text);
      _controller.clear();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Handle Backspace at beginning - delete empty todo
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.text.isEmpty &&
            widget.record != null &&
            widget.onDelete != null) {
          widget.onDelete!();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.record?.metadata['checked'] ?? false;

    // Apply 30% opacity when empty, 100% when not empty or focused
    final checkboxOpacity = (widget.isEmpty && !_isFocused) ? 0.3 : 1.0;

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
              child: Opacity(
                opacity: checkboxOpacity,
                child: Checkbox(
                  value: checked,
                  onChanged: widget.record != null && widget.onUpdate != null
                      ? (val) => widget.onUpdate!({'checked': val ?? false})
                      : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
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
