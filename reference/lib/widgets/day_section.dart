import 'package:flutter/material.dart';
import '../models/record.dart';
import 'package:lifelog_reference/services/date_service.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_section.dart';

/// DaySection represents a single day in the infinite scroll journal.
///
/// With the unified record system, there is ONE section per day (not two like the
/// old todo/note split). Records of any type can be interleaved freely.
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
    final isToday = DateService.isToday(date);

    return FutureBuilder<List<Record>>(
      future: recordsFuture,
      // FutureBuilder snapshot.connectionState: waiting → done → (error).
      // See: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html
      builder: (context, snapshot) {
        // P2: Show a subtle inline spinner while the DB query runs.
        // Without this, slower devices flash an empty section before records appear.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            // Use spacing (24px) so the spinner has the same visual weight as the
            // section header (sectionTopPadding 16 + sectionHeaderBottomPadding 8 = 24).
            padding: const EdgeInsets.symmetric(
              vertical: GridConstants.spacing,
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }

        final records = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            final leftPadding = GridConstants.calculateContentLeftPadding(
              constraints.maxWidth,
            );
            final rightPadding = GridConstants.calculateContentRightPadding(
              constraints.maxWidth,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    leftPadding,
                    GridConstants.sectionTopPadding,
                    rightPadding,
                    GridConstants.sectionHeaderBottomPadding,
                  ),
                  child: SizedBox(
                    height: GridConstants.spacing,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isToday
                            ? 'TODAY · ${DateService.formatForDisplay(date).toUpperCase()}'
                            : DateService.formatForDisplay(date).toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                // Minimum height ensures empty days feel like blank pages,
                // not collapsed rows — same visual weight whether filled or not.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: GridConstants.spacing * 4,
                  ),
                  child: RecordSection(
                    key: getSectionKey(date),
                    records: records,
                    date: date,
                    onSave: onSave,
                    onDelete: onDelete,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
