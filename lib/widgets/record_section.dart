import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import 'record_widget.dart';

class RecordSection extends StatelessWidget {
  final String title;
  final List<Record> records;
  final Record placeholderTemplate; // Used to create new records
  final Function(Record) onSave;
  final Function(String) onDelete;

  const RecordSection({
    super.key,
    required this.title,
    required this.records,
    required this.placeholderTemplate,
    required this.onSave,
    required this.onDelete,
  });

  void _handlePlaceholderSave(Record updatedPlaceholder) {
    // Create a brand new record with a fresh ID
    final uuid = const Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;

    Record newRecord;
    if (updatedPlaceholder is TodoRecord) {
      newRecord = TodoRecord(
        id: uuid.v4(),
        date: updatedPlaceholder.date,
        content: updatedPlaceholder.content,
        createdAt: now,
        updatedAt: now,
        checked: false,
      );
    } else {
      newRecord = NoteRecord(
        id: uuid.v4(),
        date: updatedPlaceholder.date,
        content: updatedPlaceholder.content,
        createdAt: now,
        updatedAt: now,
      );
    }

    onSave(newRecord);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
          ),
        ),
        // Existing records
        ...records.map((record) => RecordWidget(
              key: ValueKey(record.id),
              record: record,
              onSave: onSave,
              onDelete: onDelete,
            )),
        // Placeholder (always one at the end)
        RecordWidget(
          key: const ValueKey('placeholder'),
          record: placeholderTemplate,
          onSave: _handlePlaceholderSave,
          onDelete: (_) {}, // Placeholder can't be deleted
        ),
      ],
    );
  }
}
