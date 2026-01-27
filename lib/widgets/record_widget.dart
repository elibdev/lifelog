import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/record.dart';
import '../notifications/navigation_notifications.dart';

class RecordWidget extends StatefulWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)?
      onSubmitted; // Called when user presses Enter, passes record ID

  // FOCUS NODE LIFECYCLE CALLBACKS
  // RecordSection needs to track FocusNodes so it can call requestFocus() during navigation
  final int? recordIndex; // Position in parent's list (needed for tracking)
  final void Function(int index, String recordId, FocusNode node)?
      onFocusNodeCreated;
  final void Function(String recordId)? onFocusNodeDisposed;

  const RecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    // Focus node lifecycle callbacks - optional
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
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
    _setupFocusNode();
  }

  // FOCUS LIFECYCLE: Setup
  void _setupFocusNode() {
    // Create FocusNode
    _focusNode = FocusNode();

    // Register with parent if callback provided (for custom focus registry)
    widget.onFocusNodeCreated?.call(
      widget.recordIndex ?? -1,
      widget.record.id,
      _focusNode,
    );

    // Attach focus change listener (deletes empty records on blur)
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    // No rebuild needed - TextField handles its own focus styling
    // Removing setState prevents interference with keyboard dismiss animation

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
    _teardownFocusNode();
    super.dispose();
  }

  // FOCUS LIFECYCLE: Cleanup
  void _teardownFocusNode() {
    // Remove listener first (good practice before disposal)
    _focusNode.removeListener(_handleFocusChange);

    // Unregister from parent if callback provided
    widget.onFocusNodeDisposed?.call(widget.record.id);

    // Dispose FocusNode to prevent memory leaks
    _focusNode.dispose();
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

  // KEYBOARD SHORTCUTS: Main handler delegates to specialized handlers
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Try navigation shortcuts first (arrow keys)
    final navResult = _handleNavigationKey(event, node);
    if (navResult == KeyEventResult.handled) return navResult;

    // Then try action shortcuts (Ctrl+Enter, Delete)
    final actionResult = _handleActionKey(event);
    if (actionResult == KeyEventResult.handled) return actionResult;

    return KeyEventResult.ignored;
  }

  // NAVIGATION SHORTCUTS: Arrow keys for moving between records
  //
  // KEY REPEAT: Flutter emits three types of keyboard events:
  // - KeyDownEvent: Fired ONCE when key is first pressed
  // - KeyRepeatEvent: Fired REPEATEDLY while key is held down (OS key repeat rate)
  // - KeyUpEvent: Fired ONCE when key is released
  //
  // WHY WE HANDLE BOTH KeyDownEvent AND KeyRepeatEvent:
  // To support "hold to navigate", we need to respond to both the initial press
  // (KeyDownEvent) and the continuous repeat events (KeyRepeatEvent) that fire
  // while the user holds the arrow key down.
  //
  // EXAMPLE:
  // User holds down arrow key for 2 seconds:
  //   1. KeyDownEvent → navigate once
  //   2. KeyRepeatEvent → navigate again (after OS delay, ~500ms)
  //   3. KeyRepeatEvent → navigate again (~30ms later)
  //   4. KeyRepeatEvent → navigate again (~30ms later)
  //   ... continues until key is released
  //   N. KeyUpEvent → ignored (we don't navigate on key release)
  KeyEventResult _handleNavigationKey(KeyEvent event, FocusNode node) {
    // Only handle KeyDownEvent (initial press) and KeyRepeatEvent (key held)
    // Ignore KeyUpEvent (we don't want to navigate when key is released)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return _handleArrowDown(node);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return _handleArrowUp(node);
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleArrowDown(FocusNode node) {
    // DISPATCH NOTIFICATION: This bubbles up the widget tree
    // RecordSection will try to handle it first (focus next record in section)
    // If RecordSection can't handle it (at end), it bubbles to JournalScreen
    NavigateDownNotification(
      recordId: widget.record.id,
      recordIndex: widget.recordIndex ?? -1,
      date: widget.record.date,
      sectionType: widget.record.type,
    ).dispatch(context);

    // ⚠️ IMPORTANT: TWO SEPARATE EVENT SYSTEMS AT WORK HERE!
    //
    // SYSTEM 1: Key Event Handling (what we're doing right here)
    // - Managed by Focus widget's onKeyEvent callback
    // - KeyEventResult.handled = "I consumed this key, don't pass it to other Focus widgets"
    // - KeyEventResult.ignored = "I don't care about this key, let it bubble to other Focus widgets"
    //
    // SYSTEM 2: Notification System (what happens above in dispatch())
    // - Managed by NotificationListener widgets up the tree
    // - Listener returns true = "Stop bubbling this notification"
    // - Listener returns false = "Continue bubbling this notification to parent"
    //
    // WHY WE RETURN "HANDLED" EVEN THOUGH THE NOTIFICATION MIGHT BUBBLE:
    // We're saying "I handled the KEY PRESS" (don't let other widgets respond to arrow down),
    // NOT "I handled the navigation" (that's decided by the NotificationListener chain).
    //
    // EXAMPLE: Arrow down pressed on this TextField
    //   1. Focus widget catches the key event
    //   2. We dispatch NavigateDownNotification (Notification System)
    //   3. We return KeyEventResult.handled (Key Event System)
    //   4. Notification bubbles: RecordSection → JournalScreen (separate from key event)
    //   5. Key event stops here (because we said "handled")
    //
    // If we returned KeyEventResult.ignored, the arrow key would ALSO bubble through
    // the Focus tree, potentially causing other widgets (like scroll containers) to
    // respond to the arrow key, creating double behavior!
    return KeyEventResult.handled;
  }

  KeyEventResult _handleArrowUp(FocusNode node) {
    // DISPATCH NOTIFICATION: This bubbles up the widget tree
    // RecordSection will try to handle it first (focus previous record in section)
    // If RecordSection can't handle it (at start), it bubbles to JournalScreen
    NavigateUpNotification(
      recordId: widget.record.id,
      recordIndex: widget.recordIndex ?? -1,
      date: widget.record.date,
      sectionType: widget.record.type,
    ).dispatch(context);

    return KeyEventResult.handled;
  }

  // ACTION SHORTCUTS: Ctrl+Enter toggles checkbox, Delete removes empty
  KeyEventResult _handleActionKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final record = widget.record;
    final isEmpty = _controller.text.trim().isEmpty;

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
    if ((event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete) &&
        isEmpty &&
        _controller.selection.start == 0) {
      widget.onDelete(widget.record.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
                  // Checkbox is now focusable (Tab includes it, arrow keys skip it)
                  ? Checkbox(
                      value: record.checked,
                      onChanged: isEmpty ? null : _handleCheckboxToggle,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
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
              onKeyEvent: _handleKeyEvent,
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
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  _handleTextChange();
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
