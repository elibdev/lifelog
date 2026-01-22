import 'package:flutter/material.dart';
import '../models/record.dart';
import '../utils/debouncer.dart';

class RecordWidget extends StatefulWidget {
  final Record? record; // null for placeholder
  final Function(Record) onSave;
  final Function(String) onDelete;

  const RecordWidget({
    super.key,
    this.record,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<RecordWidget> createState() => _RecordWidgetState();
}

class _RecordWidgetState extends State<RecordWidget> {
  late TextEditingController _controller;
  late Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.record?.content ?? '');
    _debouncer = Debouncer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;

    // Debounce the save operation
    _debouncer.call(() {
      if (widget.record == null) {
        // Placeholder received text - create new record
        if (text.isNotEmpty) {
          _createNewRecord(text);
        }
      } else {
        // Existing record
        if (text.isEmpty) {
          // Content cleared - delete record
          widget.onDelete(widget.record!.id);
        } else if (text != widget.record!.content) {
          // Content changed - update record
          _updateRecord(text);
        }
      }
    });
  }

  void _createNewRecord(String content) {
    // This will be called by RecordSection which knows the record type
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedRecord = widget.record!.copyWith(
      content: content,
      updatedAt: now,
    );
    widget.onSave(updatedRecord);
  }

  void _updateRecord(String content) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedRecord = widget.record!.copyWith(
      content: content,
      updatedAt: now,
    );
    widget.onSave(updatedRecord);
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
    final isPlaceholder = widget.record == null;
    final record = widget.record;

    return Opacity(
      opacity: isPlaceholder ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading widget (polymorphic!)
            if (record != null)
              GestureDetector(
                onTap: record is TodoRecord
                    ? () => _handleCheckboxToggle(!(record as TodoRecord).checked)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12.0, right: 8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: record is TodoRecord
                        ? Checkbox(
                            value: (record as TodoRecord).checked,
                            onChanged: _handleCheckboxToggle,
                          )
                        : const Icon(Icons.circle, size: 8),
                  ),
                ),
              ),
            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: record?.hintText ?? 'Type here...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                onChanged: (_) => _handleTextChange(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
