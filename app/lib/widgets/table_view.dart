import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

/// Spreadsheet-style table view: one row per record, one column per field.
/// Content is shown as just another column. Compact, scannable, ideal for
/// comparing records and bulk review.
///
/// Uses a horizontally scrollable DataTable inside a vertically scrollable
/// SingleChildScrollView, so it handles more columns than the screen width.
/// See: https://api.flutter.dev/flutter/material/DataTable-class.html
class TableView extends StatelessWidget {
  final List<Record> records;
  final List<Field> fields;
  final ValueChanged<Record> onRecordTap;

  const TableView({
    super.key,
    required this.records,
    required this.fields,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter out relation fields — they don't display inline well.
    final visibleFields =
        fields.where((f) => f.fieldType != FieldType.relation).toList();

    // Build column headers: one for each field, plus a "Notes" column if any
    // records have content.
    final hasContent = records.any((r) => r.content.trim().isNotEmpty);

    final columns = <DataColumn>[
      for (final field in visibleFields)
        DataColumn(
          label: Text(
            field.name,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (hasContent)
        DataColumn(
          label: Text(
            'Notes',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];

    final rows = <DataRow>[
      for (final record in records)
        DataRow(
          // `onSelectChanged` on DataRow makes the entire row tappable.
          // Passing any callback enables the tap — we ignore the bool param.
          onSelectChanged: (_) => onRecordTap(record),
          cells: [
            for (final field in visibleFields)
              DataCell(
                _buildCell(context, field, record.getValue(field.id), colorScheme),
              ),
            if (hasContent)
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    record.content.trim().replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
    ];

    // Wrap in scrollable both ways so wide schemas don't overflow.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          // `showCheckboxColumn: false` hides the default selection checkboxes
          // that DataTable adds when rows have onSelectChanged.
          showCheckboxColumn: false,
          columnSpacing: 16,
          horizontalMargin: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 36,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    Field field,
    dynamic value,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    if (value == null) {
      return Text('—', style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ));
    }

    switch (field.fieldType) {
      case FieldType.checkbox:
        return Icon(
          value == true ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18,
          color: value == true ? colorScheme.primary : colorScheme.outline,
        );
      case FieldType.select:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.toString(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        );
      case FieldType.date:
      case FieldType.text:
      case FieldType.number:
        return Text(
          value.toString(),
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case FieldType.relation:
        return const SizedBox.shrink();
    }
  }
}
