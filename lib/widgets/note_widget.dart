import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/journal_record.dart';

class NoteWidget extends StatefulWidget {
  final JournalRecord? record; // null if ephemeral
  final Function(Map<String, dynamic>)? onUpdate;
  final Function(String)? onCreate;
  final VoidCallback? onCreateAfter;
  final VoidCallback? onDelete;

  const NoteWidget({
    super.key,
    this.record,
    this.onUpdate,
    this.onCreate,
    this.onCreateAfter,
    this.onDelete,
  });

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final content = widget.record?.metadata['content'] ?? '';
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
      // Handle Enter key - create new note after this one
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final text = _controller.text;

        // Save current content first
        _debounce?.cancel();
        _saveNow(text);

        // Create new note after this one
        if (widget.record != null && widget.onCreateAfter != null) {
          widget.onCreateAfter!();
        } else if (widget.onCreate != null && text.isNotEmpty) {
          widget.onCreate!(text);
        }

        return KeyEventResult.handled;
      }

      // Handle Backspace at beginning - delete empty note
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.text.isEmpty && widget.record != null && widget.onDelete != null) {
          widget.onDelete!();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: const BoxDecoration(
                color: Color(0xFF8B7355),
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
