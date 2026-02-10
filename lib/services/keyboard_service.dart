import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/record.dart';
import '../models/block.dart';
import '../notifications/navigation_notifications.dart';

// WHAT IS THIS SERVICE?
// KeyboardService handles all keyboard shortcuts for record input fields.
// It provides static methods that process KeyEvents and return KeyEventResults.
//
// WHY DOES THIS SERVICE EXIST?
// Before this refactor, RecordWidget contained 127 lines (36% of the widget)
// dedicated to keyboard handling logic:
//   - _handleKeyEvent() - Main dispatcher
//   - _handleNavigationKey() - Arrow key logic
//   - _handleArrowDown() / _handleArrowUp() - Navigation notifications
//   - _handleActionKey() - Ctrl+Enter, Delete/Backspace logic
//
// By extracting keyboard logic into a service, we:
//   1. SEPARATE CONCERNS: UI rendering (widget) vs input handling (service)
//   2. TESTABILITY: Can unit test keyboard logic without widgets
//   3. REUSABILITY: Other widgets can use the same keyboard handling
//   4. MAINTAINABILITY: Keyboard shortcuts defined in one place
//
// WHEN TO USE SERVICES VS MIXINS:
//   - Services: Pure logic, no widget lifecycle access (like this)
//   - Mixins: When you need access to widget lifecycle (initState, dispose, etc.)
//
// HOW TO USE:
// In your widget's Focus.onKeyEvent callback:
//   Focus(
//     onKeyEvent: (node, event) {
//       return KeyboardService.handleRecordKeyEvent(
//         event: event,
//         node: node,
//         record: widget.record,
//         recordIndex: widget.recordIndex,
//         textController: _controller,
//         context: context,
//         onDelete: widget.onDelete,
//         onToggleCheckbox: _handleCheckboxToggle,
//       );
//     },
//     child: TextField(...),
//   )
class KeyboardService {
  // Private constructor prevents instantiation (force static usage)
  KeyboardService._();

  /// Main keyboard event handler for record input fields
  ///
  /// Handles:
  /// - Arrow up/down: Navigate between records
  /// - Ctrl/Cmd+Enter: Toggle todo checkbox
  /// - Delete/Backspace: Delete empty record
  ///
  /// Returns:
  /// - KeyEventResult.handled: This key was processed, don't bubble
  /// - KeyEventResult.ignored: This key wasn't for us, let it bubble
  ///
  /// TWO EVENT SYSTEMS AT WORK:
  /// 1. Key Event System (what we return here)
  ///    - handled = stop key from reaching other Focus widgets
  ///    - ignored = let key bubble to other Focus widgets
  /// 2. Notification System (NavigateUp/DownNotification)
  ///    - Separate from key events, bubbles through NotificationListeners
  ///    - We can return "handled" for the key while notification still bubbles
  static KeyEventResult handleRecordKeyEvent({
    required KeyEvent event,
    required FocusNode node,
    required Record record,
    required int recordIndex,
    required TextEditingController textController,
    required BuildContext context,
    required Function(String) onDelete,
    required Function(bool) onToggleCheckbox,
  }) {
    // Try navigation shortcuts first (arrow keys)
    final navResult = _handleNavigationKey(
      event: event,
      node: node,
      record: record,
      recordIndex: recordIndex,
      context: context,
    );
    if (navResult == KeyEventResult.handled) return navResult;

    // Then try action shortcuts (Ctrl+Enter, Delete)
    final actionResult = _handleActionKey(
      event: event,
      record: record,
      textController: textController,
      onDelete: onDelete,
      onToggleCheckbox: onToggleCheckbox,
    );
    if (actionResult == KeyEventResult.handled) return actionResult;

    return KeyEventResult.ignored;
  }

  /// Handle navigation keys (arrow up/down)
  ///
  /// KEY REPEAT BEHAVIOR:
  /// Flutter emits three types of keyboard events:
  /// - KeyDownEvent: Fired ONCE when key is first pressed
  /// - KeyRepeatEvent: Fired REPEATEDLY while key is held (OS key repeat rate)
  /// - KeyUpEvent: Fired ONCE when key is released
  ///
  /// We handle both KeyDownEvent and KeyRepeatEvent to support "hold to navigate"
  /// where holding the arrow key continuously moves between records.
  ///
  /// EXAMPLE: User holds arrow down for 2 seconds
  ///   1. KeyDownEvent → navigate once
  ///   2. (500ms delay)
  ///   3. KeyRepeatEvent → navigate again
  ///   4. (30ms delay)
  ///   5. KeyRepeatEvent → navigate again
  ///   ... continues until key released
  ///   N. KeyUpEvent → ignored (don't navigate on release)
  static KeyEventResult _handleNavigationKey({
    required KeyEvent event,
    required FocusNode node,
    required Record record,
    required int recordIndex,
    required BuildContext context,
  }) {
    // Only handle KeyDownEvent (initial press) and KeyRepeatEvent (key held)
    // Ignore KeyUpEvent (we don't navigate on key release)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return _handleArrowDown(
        record: record,
        recordIndex: recordIndex,
        context: context,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return _handleArrowUp(
        record: record,
        recordIndex: recordIndex,
        context: context,
      );
    }

    return KeyEventResult.ignored;
  }

  /// Handle arrow down: Navigate to next record
  ///
  /// NOTIFICATION BUBBLING PATTERN:
  /// This dispatches a NavigateDownNotification which bubbles up the tree:
  ///   RecordWidget (here) → RecordSection → JournalScreen
  ///
  /// RecordSection tries to handle it first (focus next record in same section).
  /// If it can't (at end of section), the notification bubbles to JournalScreen
  /// which intelligently navigates to the next logical section.
  ///
  /// VISUAL FLOW:
  ///   User presses arrow down on last todo
  ///        ↓ dispatch NavigateDownNotification
  ///   RecordSection receives it, tries to focus next record
  ///        ↓ index out of bounds, return false (continue bubbling)
  ///   JournalScreen receives it, knows to navigate to first note
  ///        ↓ calls key.currentState?.focusFirstRecord()
  ///   First note field gets focus ✅
  ///
  /// TWO SYSTEMS: Why we return "handled" even though notification bubbles
  /// - Key Event System: "handled" means no other Focus widgets see this key
  /// - Notification System: Separate, continues bubbling independently
  /// - This prevents scroll containers from also responding to arrow key
  static KeyEventResult _handleArrowDown({
    required Record record,
    required int recordIndex,
    required BuildContext context,
  }) {
    // Dispatch notification (bubbles up through NotificationListeners)
    NavigateDownNotification(
      recordId: record.id,
      recordIndex: recordIndex,
      date: record.date,
      sectionType: record.type,
    ).dispatch(context);

    // Return "handled" to stop key from reaching other Focus widgets
    // (prevents scroll containers from also responding)
    return KeyEventResult.handled;
  }

  /// Handle arrow up: Navigate to previous record
  ///
  /// Same bubbling logic as arrow down, but in reverse direction.
  /// See _handleArrowDown comments for detailed explanation.
  static KeyEventResult _handleArrowUp({
    required Record record,
    required int recordIndex,
    required BuildContext context,
  }) {
    // Dispatch notification (bubbles up through NotificationListeners)
    NavigateUpNotification(
      recordId: record.id,
      recordIndex: recordIndex,
      date: record.date,
      sectionType: record.type,
    ).dispatch(context);

    // Return "handled" to stop key from reaching other Focus widgets
    return KeyEventResult.handled;
  }

  /// Handle action keys (Ctrl+Enter, Delete/Backspace)
  ///
  /// Supported actions:
  /// 1. Ctrl/Cmd+Enter: Toggle todo checkbox (only for non-empty todos)
  /// 2. Delete/Backspace: Delete empty record when cursor at start
  ///
  /// WHY ONLY KEYDOWNEVENT:
  /// Action keys should only fire once per press (not on repeat).
  /// We don't want holding Ctrl+Enter to rapidly toggle checkbox!
  static KeyEventResult _handleActionKey({
    required KeyEvent event,
    required Record record,
    required TextEditingController textController,
    required Function(String) onDelete,
    required Function(bool) onToggleCheckbox,
  }) {
    // Only respond to initial key press, not repeats or releases
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isEmpty = textController.text.trim().isEmpty;

    // Ctrl/Cmd+Enter: Toggle checkbox (for non-empty todos only)
    //
    // WHY CHECK "!isEmpty":
    // Empty todos should be deleted, not toggled. This prevents accidentally
    // marking an empty todo as complete.
    //
    // WHY CTRL AND META:
    // - Windows/Linux: Ctrl key (HardwareKeyboard.isControlPressed)
    // - macOS: Cmd key (HardwareKeyboard.isMetaPressed)
    // We check both for cross-platform compatibility.
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        record is TodoRecord &&
        !isEmpty) {
      // Toggle to opposite state
      onToggleCheckbox(!record.checked);
      return KeyEventResult.handled;
    }

    // Delete/Backspace: Delete empty record when cursor at start
    //
    // CONDITIONS REQUIRED:
    // 1. Text field is empty (isEmpty = true)
    // 2. Cursor is at position 0 (selection.start == 0)
    // 3. User pressed Delete or Backspace
    //
    // WHY CHECK CURSOR POSITION:
    // If cursor is NOT at start, we want default backspace behavior
    // (delete character). Only if at start of empty field do we delete
    // the entire record.
    //
    // EXAMPLE:
    //   Empty field, cursor at start, press Backspace → delete record ✅
    //   Empty field, cursor at end, press Backspace → do nothing (let TextField handle) ✅
    //   "Hello|", press Backspace → delete "o", becomes "Hell|" ✅
    if ((event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete) &&
        isEmpty &&
        textController.selection.start == 0) {
      onDelete(record.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ==========================================================================
  // BLOCK-BASED KEYBOARD HANDLING
  // Same logic as Record-based handling, adapted for the new Block model.
  // ==========================================================================

  /// Keyboard event handler for Block-based input fields.
  /// Used by BlockTextField in the new adaptive block system.
  static KeyEventResult handleBlockKeyEvent({
    required KeyEvent event,
    required FocusNode node,
    required Block block,
    required int blockIndex,
    required TextEditingController textController,
    required BuildContext context,
    required Function(String) onDelete,
    required Function(bool) onToggleCheckbox,
  }) {
    // Navigation (arrow keys)
    final navResult = _handleBlockNavigationKey(
      event: event,
      block: block,
      blockIndex: blockIndex,
      context: context,
    );
    if (navResult == KeyEventResult.handled) return navResult;

    // Action keys (Ctrl+Enter, Delete)
    final actionResult = _handleBlockActionKey(
      event: event,
      block: block,
      textController: textController,
      onDelete: onDelete,
      onToggleCheckbox: onToggleCheckbox,
    );
    if (actionResult == KeyEventResult.handled) return actionResult;

    return KeyEventResult.ignored;
  }

  static KeyEventResult _handleBlockNavigationKey({
    required KeyEvent event,
    required Block block,
    required int blockIndex,
    required BuildContext context,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // With blocks, sectionType is always 'blocks' (one section per day)
      NavigateDownNotification(
        recordId: block.id,
        recordIndex: blockIndex,
        date: block.date,
        sectionType: 'blocks',
      ).dispatch(context);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      NavigateUpNotification(
        recordId: block.id,
        recordIndex: blockIndex,
        date: block.date,
        sectionType: 'blocks',
      ).dispatch(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  static KeyEventResult _handleBlockActionKey({
    required KeyEvent event,
    required Block block,
    required TextEditingController textController,
    required Function(String) onDelete,
    required Function(bool) onToggleCheckbox,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isEmpty = textController.text.trim().isEmpty;

    // Ctrl/Cmd+Enter: Toggle checkbox (for non-empty todo blocks only)
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        block.type == BlockType.todo &&
        !isEmpty) {
      onToggleCheckbox(!block.isChecked);
      return KeyEventResult.handled;
    }

    // Delete/Backspace: Delete empty block when cursor at start
    if ((event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete) &&
        isEmpty &&
        textController.selection.start == 0) {
      onDelete(block.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
