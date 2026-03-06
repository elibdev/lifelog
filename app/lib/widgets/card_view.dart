import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

/// Trello-style card view: compact cards focused on structured field values.
/// Content text is shown only as a secondary preview — tapping opens an edit
/// modal. Designed for project-management-style scanning of many records.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Collect fields that have values set on this record.
    final populatedFields = <(Field, String)>[];
    for (final field in fields) {
      final value = record.getValue(field.id);
      if (value == null) continue;
      final display = _formatValue(field, value);
      if (display.isEmpty) continue;
      populatedFields.add((field, display));
    }

    // Content preview: first non-empty line, only if content exists.
    final contentPreview = record.content.trim().isNotEmpty
        ? record.content.trim().split('\n').first
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        // `borderRadius` on InkWell clips the ripple to match the Card shape.
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field values as compact chips — the primary content of a card.
              if (populatedFields.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final (field, display) in populatedFields)
                      _FieldBadge(
                        field: field,
                        display: display,
                        colorScheme: colorScheme,
                      ),
                  ],
                ),

              // Content preview — secondary, only if there's text.
              if (contentPreview != null) ...[
                if (populatedFields.isNotEmpty) const SizedBox(height: 6),
                Text(
                  contentPreview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatValue(Field field, dynamic value) {
    switch (field.fieldType) {
      // P1: Show both checked and unchecked states so users can
      // distinguish "unchecked" from "field not set".
      case FieldType.checkbox:
        return value == true ? '✓' : '☐';
      case FieldType.date:
      case FieldType.text:
      case FieldType.number:
      case FieldType.select:
        final s = value.toString();
        return s;
      case FieldType.relation:
        return '';
    }
  }
}

/// Compact badge showing a single field value. Checkbox fields with false
/// values are filtered out upstream; here we just render what's given.
class _FieldBadge extends StatelessWidget {
  final Field field;
  final String display;
  final ColorScheme colorScheme;

  const _FieldBadge({
    required this.field,
    required this.display,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Checkbox gets a small icon — checked or unchecked.
    if (field.fieldType == FieldType.checkbox) {
      return display == '✓'
          ? Icon(Icons.check_circle_outline, size: 16, color: colorScheme.primary)
          : Icon(Icons.circle_outlined, size: 16, color: colorScheme.outline);
    }

    // Select fields get a tinted background to stand out.
    if (field.fieldType == FieldType.select) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          display,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
        ),
      );
    }

    // Everything else: plain label text.
    return Text(
      '${field.name}: $display',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
    );
  }
}
