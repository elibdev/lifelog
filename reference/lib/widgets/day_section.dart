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
