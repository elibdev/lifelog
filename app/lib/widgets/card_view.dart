import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';
import 'display_helpers.dart';

/// Trello-style card view: compact cards focused on structured field values.
/// Content text is shown only as a secondary preview — tapping opens an edit
/// modal. Designed for project-management-style scanning of many records.
class CardView extends StatelessWidget {
  final List<Record> records;
  final List<Field> fields;
  final ValueChanged<Record> onRecordTap;

  /// When non-null, the list becomes reorderable with drag handles.
  final void Function(int oldIndex, int newIndex)? onRecordReordered;

  const CardView({
    super.key,
    required this.records,
    required this.fields,
    required this.onRecordTap,
    this.onRecordReordered,
  });

  @override
  Widget build(BuildContext context) {
    if (onRecordReordered != null) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        buildDefaultDragHandles: false,
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return _RecordCard(
            key: ValueKey(record.id),
            record: record,
            fields: fields,
            onTap: () => onRecordTap(record),
            dragIndex: index,
          );
        },
        onReorder: onRecordReordered!,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _RecordCard(
          key: ValueKey(record.id),
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
  final int? dragIndex;

  const _RecordCard({
    super.key,
    required this.record,
    required this.fields,
    required this.onTap,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Collect fields that have displayable values.
    final badges = <Widget>[];
    for (final field in fields) {
      final value = record.getValue(field.id);
      if (value == null) continue;

      // Checkbox: show star icon only when true, hide when false.
      if (field.fieldType == FieldType.checkbox) {
        if (value == true) {
          badges.add(Icon(Icons.star_rounded, size: 16, color: colorScheme.primary));
        }
        continue;
      }

      final display = value.toString();
      if (display.isEmpty) continue;

      // Select fields: semantic color badges.
      if (field.fieldType == FieldType.select) {
        final colors = selectOptionColors(
          value: display,
          options: field.selectOptions,
          colorScheme: colorScheme,
        );
        badges.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            display,
            style: theme.textTheme.labelSmall?.copyWith(color: colors.fg),
          ),
        ));
        continue;
      }

      // Relation fields: skip.
      if (field.fieldType == FieldType.relation) continue;

      // Text, number, date: plain label.
      badges.add(Text(
        '${field.name}: $display',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ));
    }

    // Content preview: first non-empty line.
    final contentPreview = record.content.trim().isNotEmpty
        ? record.content.trim().split('\n').first
        : null;

    // Date from createdAt timestamp.
    final dateStr = formatRecordDate(record.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle on the leading edge when reordering is enabled.
              if (dragIndex != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: field badges + date aligned right.
                    if (badges.isNotEmpty || dateStr.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: badges,
                            ),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),

                    // Content preview.
                    if (contentPreview != null) ...[
                      if (badges.isNotEmpty) const SizedBox(height: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}
