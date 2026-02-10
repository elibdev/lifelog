import 'package:flutter/material.dart';
import '../models/block.dart';
import '../services/date_service.dart';
import '../constants/grid_constants.dart';
import 'dotted_grid_decoration.dart';
import 'block_section.dart';

/// DaySection represents a single day in the infinite scroll journal.
///
/// Displays:
///   1. Date header (e.g., "Today · Mon, Jan 27, 2025")
///   2. A single BlockSection containing all blocks for that day (mixed types)
///
/// With the block system, there is ONE section per day (not two like the old
/// todo/note split). Blocks of any type can be interleaved freely.
class DaySection extends StatelessWidget {
  final String date;
  final Future<List<Block>> blocksFuture;

  // GlobalKey for the BlockSection, enabling cross-day keyboard navigation
  final GlobalKey<BlockSectionState> Function(String date) getSectionKey;

  final Function(Block) onSave;
  final Function(String) onDelete;

  const DaySection({
    super.key,
    required this.date,
    required this.blocksFuture,
    required this.getSectionKey,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateService.isToday(date);

    // FutureBuilder: lazy loading — only loads blocks when scrolled into view
    return FutureBuilder<List<Block>>(
      future: blocksFuture,
      builder: (context, snapshot) {
        final blocks = snapshot.data ?? [];

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
                  // Date header
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

                  // Single BlockSection for all block types (replaces two RecordSections)
                  BlockSection(
                    key: getSectionKey(date),
                    blocks: blocks,
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
