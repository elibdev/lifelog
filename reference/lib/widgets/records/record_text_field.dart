import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../notifications/navigation_notifications.dart';
import '../../services/keyboard_service.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';

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
  // C2: prevents editing in read-only contexts (e.g. search results)
  final bool readOnly;

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
    this.readOnly = false,
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
    // C2: never auto-delete in read-only mode (search results)
    if (widget.readOnly) return;
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

  // C1: Convert the current text record to a different type via slash command.
  // Returns the converted Record, or null if text is not a recognized command.
  // Supported: /todo  /h1  /h2  /h3  /bullet  /habit
  Record? _applySlashCommand(String text) {
    final cmd = text.trim().toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = widget.record.copyWith(content: '', updatedAt: now);

    return switch (cmd) {
      '/todo' => base.copyWith(
          type: RecordType.todo,
          metadata: {'todo.checked': false},
        ),
      '/h1' => base.copyWith(
          type: RecordType.heading,
          metadata: {'heading.level': 1},
        ),
      '/h2' => base.copyWith(
          type: RecordType.heading,
          metadata: {'heading.level': 2},
        ),
      '/h3' => base.copyWith(
          type: RecordType.heading,
          metadata: {'heading.level': 3},
        ),
      '/bullet' => base.copyWith(
          type: RecordType.bulletList,
          metadata: {'bulletList.indentLevel': 0},
        ),
      '/habit' => base.copyWith(
          type: RecordType.habit,
          metadata: {
            'habit.name': '',
            'habit.completions': <String>[],
            'habit.frequency': 'daily',
            'habit.archived': false,
          },
        ),
      _ => null,
    };
  }

  void _handleTextChange() {
    final text = _controller.text;

    // C1: Slash command detection — only on non-empty lines starting with '/'
    if (!widget.readOnly && text.startsWith('/') && text.trim().length > 1) {
      final converted = _applySlashCommand(text);
      if (converted != null) {
        _controller.text = '';
        widget.onSave(converted);
        RefocusRecordNotification(recordId: widget.record.id).dispatch(context);
        return;
      }
    }

    if (text != widget.record.content) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = widget.record.copyWith(content: text, updatedAt: now);
      widget.onSave(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final defaultStyle = theme.textTheme.bodyMedium?.copyWith(
      height: GridConstants.textLineHeightMultiplier,
    );
    final effectiveStyle = widget.textStyle ?? defaultStyle;

    return Focus(
      onKeyEvent: (node, event) {
        if (widget.readOnly) return KeyEventResult.ignored;
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
        // C2: readOnly allows text selection (copy) but prevents editing
        readOnly: widget.readOnly,
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
        style: effectiveStyle,
        cursorColor: theme.colorScheme.primary,
        cursorWidth: 1.5,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _handleTextChange(),
        onSubmitted: (_) {
          if (widget.readOnly) return;
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
