import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/record.dart';
import 'package:lifelog_reference/notifications/navigation_notifications.dart';

/// Keyboard event handler for the new Record model.
///
/// Handles arrow navigation, Ctrl+Enter checkbox toggle, and Delete/Backspace
/// for empty records. Uses the existing NavigateDown/UpNotification pattern.
class KeyboardService {
  KeyboardService._();

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
    final navResult = _handleNavigationKey(
      event: event,
      record: record,
      recordIndex: recordIndex,
      context: context,
      textController: textController,
    );
    if (navResult == KeyEventResult.handled) return navResult;

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

  static KeyEventResult _handleNavigationKey({
    required KeyEvent event,
    required Record record,
    required int recordIndex,
    required BuildContext context,
    required TextEditingController textController,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // Only hijack Arrow Down when the cursor is on the last line of the field.
      // If there is a '\n' after the cursor, the default text movement handles it.
      if (!_isCursorOnLastLine(textController)) return KeyEventResult.ignored;
      NavigateDownNotification(
        recordId: record.id,
        recordIndex: recordIndex,
        date: record.date,
      ).dispatch(context);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      // Only hijack Arrow Up when the cursor is on the first line of the field.
      if (!_isCursorOnFirstLine(textController)) return KeyEventResult.ignored;
      NavigateUpNotification(
        recordId: record.id,
        recordIndex: recordIndex,
        date: record.date,
      ).dispatch(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // Returns true if the cursor (or selection start) sits on the first line,
  // meaning there is no '\n' character before it in the text.
  static bool _isCursorOnFirstLine(TextEditingController controller) {
    final cursor = controller.selection.start;
    if (cursor <= 0) return true;
    return !controller.text.substring(0, cursor).contains('\n');
  }

  // Returns true if the cursor (or selection start) sits on the last line,
  // meaning there is no '\n' character after it in the text.
  static bool _isCursorOnLastLine(TextEditingController controller) {
    final cursor = controller.selection.start;
    if (cursor < 0 || cursor >= controller.text.length) return true;
    return !controller.text.substring(cursor).contains('\n');
  }

  static KeyEventResult _handleActionKey({
    required KeyEvent event,
    required Record record,
    required TextEditingController textController,
    required Function(String) onDelete,
    required Function(bool) onToggleCheckbox,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isEmpty = textController.text.trim().isEmpty;

    // Ctrl/Cmd+Enter: Toggle checkbox (for non-empty todo records only)
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        record.type == RecordType.todo &&
        !isEmpty) {
      onToggleCheckbox(!record.isChecked);
      return KeyEventResult.handled;
    }

    // Delete/Backspace: Delete empty record when cursor at start
    if ((event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete) &&
        isEmpty &&
        textController.selection.start == 0) {
      onDelete(record.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
