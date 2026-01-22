import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import 'record_section.dart';

class DaySection extends StatelessWidget {
  final String date; // ISO8601: '2026-01-21'
  final List<Record> records;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String recordId, int direction)? onNavigate;

  const DaySection({
    super.key,
    required this.date,
    required this.records,
    required this.onSave,
    required this.onDelete,
    this.onNavigate,
  });

  String _formatDate(String isoDate) {
    final dateTime = DateTime.parse(isoDate);
    return DateFormat('EEE, MMM d').format(dateTime); // "Wed, Jan 22"
  }

  List<Widget> buildSlivers(BuildContext context, {required String todosKey, required String notesKey}) {
    // Separate records by type
    final todos = records.whereType<TodoRecord>().toList();
    final notes = records.whereType<NoteRecord>().toList();

    return [
      // Date header (not pinned, just scrolls normally)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatDate(date),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
      // Records
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordSection(
              key: ValueKey(todosKey),
              title: 'TODOS',
              records: todos,
              date: date,
              recordType: 'todo',
              onSave: onSave,
              onDelete: onDelete,
              onNavigate: onNavigate,
            ),
            RecordSection(
              key: ValueKey(notesKey),
              title: 'NOTES',
              records: notes,
              date: date,
              recordType: 'note',
              onSave: onSave,
              onDelete: onDelete,
              onNavigate: onNavigate,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Not used anymore
  }
}
