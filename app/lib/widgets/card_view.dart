import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

/// Card-based view: each record renders as a Material card with field values.
class CardView extends StatelessWidget {
  final List<Record> records;
  final List<Field> fields;
  final ValueChanged<Record> onRecordTap;

  const CardView({
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
        return _RecordCard(
          record: record,
          fields: fields,
          onTap: () => onRecordTap(record),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  final Record record;
  final List<Field> fields;
  final VoidCallback onTap;

  const _RecordCard({
    required this.record,
    required this.fields,
    required this.onTap,
  });

  /// Derives a heading from record content (first line, or 'Untitled').
  String _getHeading() {
    if (record.content.isNotEmpty) {
      return record.content.split('\n').first;
    }
    return 'Untitled';
  }

  @override
  Widget build(BuildContext context) {
    final title = _getHeading();
    // Build field summary rows for all fields with values
    final fieldRows = <Widget>[];
    for (final field in fields) {
      final value = record.getValue(field.id);
      if (value == null) continue;
      final display = _formatValue(field, value);
      if (display.isEmpty) continue;
      fieldRows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${field.name}: $display',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        // `borderRadius` on InkWell clips the ripple to match the Card shape.
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              ...fieldRows,
            ],
          ),
        ),
      ),
    );
  }

  String _formatValue(Field field, dynamic value) {
    switch (field.fieldType) {
      case FieldType.checkbox:
        return value == true ? '✓' : '✗';
      case FieldType.date:
      case FieldType.text:
      case FieldType.number:
      case FieldType.select:
        return value.toString();
      case FieldType.relation:
        return ''; // Relations shown separately
    }
  }
}
