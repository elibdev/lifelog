import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import 'record_section.dart';

class DaySection extends StatelessWidget {
  final String date; // ISO8601: '2026-01-21'
  final List<Record> records;
  final Function(Record) onSave;
  final Function(String) onDelete;

  const DaySection({
    super.key,
    required this.date,
    required this.records,
    required this.onSave,
    required this.onDelete,
  });

  String _formatDate(String isoDate) {
    final dateTime = DateTime.parse(isoDate);
    return DateFormat('EEEE, MMM d').format(dateTime); // "Wednesday, Jan 22"
  }

  @override
  Widget build(BuildContext context) {
    // Separate records by type
    final todos = records.whereType<TodoRecord>().toList();
    final notes = records.whereType<NoteRecord>().toList();

    // Create placeholder templates
    final todoPlaceholder = TodoRecord(
      id: 'placeholder-todo',
      date: date,
      content: '',
      createdAt: 0,
      updatedAt: 0,
    );

    final notePlaceholder = NoteRecord(
      id: 'placeholder-note',
      date: date,
      content: '',
      createdAt: 0,
      updatedAt: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _formatDate(date),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        // Todo section
        RecordSection(
          title: 'TODOS',
          records: todos,
          placeholderTemplate: todoPlaceholder,
          onSave: onSave,
          onDelete: onDelete,
        ),
        const SizedBox(height: 16),
        // Notes section
        RecordSection(
          title: 'NOTES',
          records: notes,
          placeholderTemplate: notePlaceholder,
          onSave: onSave,
          onDelete: onDelete,
        ),
        const Divider(height: 32),
      ],
    );
  }
}
