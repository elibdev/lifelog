import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/journal_record.dart';
import '../focus_manager.dart';
import 'record_renderer.dart';

class NoteRecordRenderer extends RecordRenderer {
  @override
  String get recordType => 'note';

  @override
  Widget build(
    BuildContext context,
    JournalRecord record,
    RecordActions actions,
  ) {
    return NoteRecordWidget(
      record: record,
      actions: actions,
    );
  }

  @override
  JournalRecord createEmpty(DateTime date, double position) {
    return JournalRecord(
      id: '', // Will be set by state manager
      date: date,
      recordType: 'note',
      position: position,
      metadata: {'content': ''},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class NoteRecordWidget extends StatefulWidget {
  final JournalRecord record;
  final RecordActions actions;

  const NoteRecordWidget({
    super.key,
    required this.record,
    required this.actions,
  });

  @override
  State<NoteRecordWidget> createState() => _NoteRecordWidgetState();
}

class _NoteRecordWidgetState extends State<NoteRecordWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounce;
  String _lastSavedContent = '';

  @override
  void initState() {
    super.initState();
    _lastSavedContent = widget.record.metadata['content'] as String? ?? '';
    _controller = TextEditingController(text: _lastSavedContent);
    _focusNode = FocusNode();

    // Register focus node with focus manager
    final focusManager = context.read<JournalFocusManager>();
    focusManager.registerRecord(
      widget.record.id,
      widget.record.date,
      _focusNode,
    );

    // Auto-focus if this is a newly created record
    if (_isNewlyCreated()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(NoteRecordWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller if record content changed externally
    final newContent = widget.record.metadata['content'] as String? ?? '';
    if (newContent != _controller.text) {
      _controller.text = newContent;
      _lastSavedContent = newContent;
    }
  }

  @override
  void dispose() {
    // Unregister focus node from focus manager
    final focusManager = context.read<JournalFocusManager>();
    focusManager.unregisterRecord(widget.record.id, widget.record.date);

    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isNewlyCreated() {
    final content = widget.record.metadata['content'] as String? ?? '';
    final createdRecently = widget.record.createdAt
        .isAfter(DateTime.now().subtract(const Duration(seconds: 1)));
    return content.isEmpty && createdRecently;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final focusManager = context.read<JournalFocusManager>();

    // Handle arrow up - move to previous record when cursor at start
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_controller.selection.start == 0) {
        if (focusManager.moveToPrevious(widget.record.id)) {
          return KeyEventResult.handled;
        }
      }
    }

    // Handle arrow down - move to next record when cursor at end
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final atEnd = _controller.selection.start == _controller.text.length;
      if (atEnd) {
        if (focusManager.moveToNext(widget.record.id)) {
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  void _onTextChanged(String text) {
    // Check for Enter key (create new record)
    if (text.endsWith('\n')) {
      // Trim the newline from current record
      final trimmedText = text.substring(0, text.length - 1);
      _controller.text = trimmedText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: trimmedText.length),
      );

      // Save the trimmed content
      if (trimmedText != _lastSavedContent) {
        _lastSavedContent = trimmedText;
        widget.actions.updateMetadata(
          widget.record.id,
          {'content': trimmedText},
        );
      }

      // Detect record type: "[ ]" creates todo, otherwise note
      String recordType = 'note';
      String initialContent = '';

      if (trimmedText.trim() == '[ ]' || trimmedText.trim() == '[]') {
        // User typed [ ] to create a todo
        recordType = 'todo';
        // Clear the current record
        _controller.text = '';
        _lastSavedContent = '';
        widget.actions.updateMetadata(
          widget.record.id,
          {'content': ''},
        );
      }

      // Create new record after this one
      final newPosition = widget.record.position + 1.0;
      final metadata = recordType == 'todo'
          ? {'content': initialContent, 'checked': false}
          : {'content': initialContent};

      widget.actions.createNewRecordAfter(
        recordType,
        newPosition,
        metadata,
      );

      return;
    }

    // Regular debounced save
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (text != _lastSavedContent) {
        _lastSavedContent = text;
        widget.actions.updateMetadata(
          widget.record.id,
          {'content': text},
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet point
          Padding(
            padding: const EdgeInsets.only(top: 6.0, right: 8.0),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF8B7355),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Note content
          Expanded(
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onTextChanged,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
