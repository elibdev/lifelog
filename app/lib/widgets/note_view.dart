import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

/// Note-style view: emphasizes the record's content (note body) with a
/// compact one-line field summary above it.
class NoteView extends StatelessWidget {
  final List<Record> records;
  final List<Field> fields;
  final ValueChanged<Record> onRecordTap;

  const NoteView({
    super.key,
    required this.records,
    required this.fields,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _NoteCard(
          record: record,
          fields: fields,
          onTap: () => onRecordTap(record),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Record record;
  final List<Field> fields;
  final VoidCallback onTap;

  const _NoteCard({
    required this.record,
    required this.fields,
    required this.onTap,
  });

  String _getTitle() {
    for (final field in fields) {
      if (field.fieldType == FieldType.text) {
        final value = record.getValue(field.id);
        if (value is String && value.isNotEmpty) return value;
      }
    }
    if (record.content.isNotEmpty) {
      return record.content.split('\n').first;
    }
    return 'Untitled';
  }

  /// Builds a compact "Author: X · Status: Y" summary line.
  String _fieldSummary() {
    final parts = <String>[];
    for (final field in fields) {
      if (field.fieldType == FieldType.relation) continue;
      final value = record.getValue(field.id);
      if (value == null || value.toString().isEmpty) continue;
      // Skip the first text field (used as title)
      if (field.fieldType == FieldType.text && parts.isEmpty) continue;
      final display = field.fieldType == FieldType.checkbox
          ? (value == true ? '✓' : '✗')
          : value.toString();
      parts.add('${field.name}: $display');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final title = _getTitle();
    final summary = _fieldSummary();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (record.content.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  record.content,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
