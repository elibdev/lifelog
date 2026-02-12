import 'package:flutter/material.dart';
import '../models/record.dart';
import 'package:lifelog_reference/services/date_service.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'package:lifelog_reference/widgets/dotted_grid_decoration.dart';
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
            final horizontalOffset = GridConstants.calculateGridOffset(
              constraints.maxWidth,
            );

            final brightness = Theme.of(context).brightness;
            final dotColor = brightness == Brightness.light
                ? GridConstants.dotColorLight
                : GridConstants.dotColorDark;

            return DecoratedBox(
              decoration: DottedGridDecoration(
                horizontalOffset: horizontalOffset,
                color: dotColor,
              ),
              child: Column(
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
                              ? 'Today · ${DateService.formatForDisplay(date)}'
                              : DateService.formatForDisplay(date),
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  RecordSection(
                    key: getSectionKey(date),
                    records: records,
                    date: date,
                    onSave: onSave,
                    onDelete: onDelete,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
