import 'package:flutter/material.dart';
import '../models/record.dart';
import '../services/date_service.dart';
import '../constants/grid_constants.dart';
import 'record_section.dart';

/// A single day in the infinite-scroll journal.
///
/// Design: Swiss-style uppercase date header with letter-spacing,
/// followed by a thin rule divider. The date label uses titleMedium
/// from the design system (12px, weight 500, tracked).
class DaySection extends StatelessWidget {
  final String date;
  final Future<List<Record>> recordsFuture;
  final GlobalKey<RecordSectionState> Function(String date) getSectionKey;
  final Function(Record) onSave;
  final Function(String) onDelete;

  const DaySection({
    super.key,
    required this.date,
    required this.recordsFuture,
    required this.getSectionKey,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateService.isToday(date);

    return FutureBuilder<List<Record>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            final leftPadding = GridConstants.calculateContentLeftPadding(
              constraints.maxWidth,
            );
            final rightPadding = GridConstants.calculateContentRightPadding(
              constraints.maxWidth,
            );

            // Format: uppercase for Swiss typographic style
            final dateLabel = isToday
                ? 'TODAY · ${DateService.formatForDisplay(date).toUpperCase()}'
                : DateService.formatForDisplay(date).toUpperCase();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header with rule
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    leftPadding,
                    GridConstants.sectionTopPadding,
                    rightPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date label — uppercase, letter-spaced
                      Text(
                        dateLabel,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Thin rule — separates header from content
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: GridConstants.sectionHeaderBottomPadding),
                // Records
                RecordSection(
                  key: getSectionKey(date),
                  records: records,
                  date: date,
                  onSave: onSave,
                  onDelete: onDelete,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
