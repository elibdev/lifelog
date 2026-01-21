import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/journal_record.dart';

class NoteWidget extends StatefulWidget {
  final JournalRecord? record; // null if ephemeral
  final bool isEmpty;
  final Function(Map<String, dynamic>)? onUpdate;
  final Function(String)? onCreate;
  final VoidCallback? onDelete;

  const NoteWidget({
    super.key,
    this.record,
    this.isEmpty = false,
    this.onUpdate,
    this.onCreate,
    this.onDelete,
  });

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
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

  void _onChanged(String text) {
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
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Handle Backspace at beginning - delete empty note
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
    // Apply 30% opacity when empty, 100% when not empty or focused
    final bulletOpacity = (widget.isEmpty && !_isFocused) ? 0.3 : 1.0;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF8B7355).withOpacity(bulletOpacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Text field
          Expanded(
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                maxLines: null,
                style: const TextStyle(fontSize: 14, height: 1.5),
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
