import 'package:flutter/material.dart';
import '../models/record.dart';
import '../services/date_service.dart';
import '../constants/grid_constants.dart';
import 'dotted_grid_decoration.dart';
import 'record_section.dart';

// WHAT IS THIS WIDGET?
// DaySection represents a single day in the infinite scroll journal.
// It displays:
//   1. Date header (e.g., "Today • Mon, Jan 27, 2025")
//   2. Todos section for that day
//   3. Notes section for that day
//
// WHY DOES THIS WIDGET EXIST?
// Before this refactor, JournalScreen had two nearly identical SliverList
// builders (one for past days, one for future days) - 74 lines of duplicated
// code! By extracting day rendering into its own widget, we:
//   - Eliminate code duplication (DRY principle)
//   - Make each day a self-contained, reusable component
//   - Reduce JournalScreen from 465 → ~320 lines (31% reduction!)
//   - Make the code easier to test and maintain
//
// HOW DOES IT WORK?
// DaySection receives:
//   - date: ISO date string (e.g., "2026-01-27")
//   - recordsFuture: Async list of records for this day
//   - getSectionKey: Function to create GlobalKeys for cross-section navigation
//   - onSave/onDelete: Callbacks to propagate record changes up to JournalScreen
//
// The widget uses a FutureBuilder to load records asynchronously (lazy loading),
// then splits them into todos and notes, and renders two RecordSections.
class DaySection extends StatelessWidget {
  // The date this section represents (ISO format: "2026-01-27")
  final String date;

  // Future that loads records for this date (supports lazy loading)
  final Future<List<Record>> recordsFuture;

  // Function to get GlobalKey for a specific section
  // Used by RecordSection to enable cross-section navigation
  // (e.g., arrow down from last todo → first note)
  final GlobalKey<RecordSectionState> Function(String date, String sectionType)
      getSectionKey;

  // Callback when a record is saved (propagates to JournalScreen)
  final Function(Record) onSave;

  // Callback when a record is deleted (propagates to JournalScreen)
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

    // FUTUREBUILDER: Lazy loading pattern
    // Only loads records when this day is scrolled into view
    // This is how we achieve infinite scrolling without loading
    // all days at once (which would be slow and memory-intensive)
    return FutureBuilder<List<Record>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        // Get records from Future (empty list while loading)
        final records = snapshot.data ?? [];

        // POLYMORPHISM: Split records by type using whereType<T>()
        // This is a type-safe way to filter a heterogeneous list
        // Alternative would be: records.where((r) => r is TodoRecord)
        // but whereType is cleaner and returns the correct type
        final todos = records.whereType<TodoRecord>().toList();
        final notes = records.whereType<NoteRecord>().toList();

        // Build the day's UI: header + todos + notes
        // LAYOUTBUILDER: Get container width to calculate grid-aligned padding
        return LayoutBuilder(
          builder: (context, constraints) {
            final leftPadding = GridConstants.calculateContentLeftPadding(
              constraints.maxWidth,
            );
            final rightPadding = GridConstants.calculateContentRightPadding(
              constraints.maxWidth,
            );

            // Calculate grid offset for the dotted background
            final horizontalOffset = GridConstants.calculateGridOffset(
              constraints.maxWidth,
            );

            // Get theme brightness for dot color
            final brightness = Theme.of(context).brightness;
            final dotColor = brightness == Brightness.light
                ? GridConstants.dotColorLight
                : GridConstants.dotColorDark;

            // DECORATEDBOX: Applies dotted grid background to this DaySection
            // Since DaySection is inside the CustomScrollView, this decoration
            // scrolls naturally as the sliver scrolls
            return DecoratedBox(
              decoration: DottedGridDecoration(
                horizontalOffset: horizontalOffset,
                color: dotColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // DATE HEADER
                // Aligns with grid columns for visual consistency
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    leftPadding,
                    GridConstants.sectionTopPadding,
                    rightPadding,
                    GridConstants.sectionHeaderBottomPadding,
                  ),
              child: Text(
                // Show "Today • " prefix if this is today's date
                isToday
                    ? 'Today • ${DateService.formatForDisplay(date)}'
                    : DateService.formatForDisplay(date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            // TODOS SECTION
            //
            // ATTACHING THE GLOBALKEY:
            // We pass the GlobalKey from JournalScreen to RecordSection.
            // This creates a "remote control" that JournalScreen can use
            // to call methods on RecordSectionState (like focusFirstRecord).
            //
            // WHY: When arrow navigation needs to jump between sections
            // (e.g., from last todo to first note), JournalScreen uses
            // the GlobalKey to directly tell the target section to focus.
            //
            // VISUAL FLOW:
            //   User presses arrow down on last todo
            //        ↓ NavigateDownNotification bubbles up
            //   JournalScreen receives notification
            //        ↓ _navigateDown(date, 'todo')
            //   JournalScreen looks up: getSectionKey(date, 'note')
            //        ↓ key.currentState?.focusFirstRecord()
            //   Notes section focuses its first text field ✅
            RecordSection(
              key: getSectionKey(date, 'todo'), // "Remote control" attached
              title: 'TODOS',
              records: todos,
              date: date,
              recordType: 'todo',
              onSave: onSave,
              onDelete: onDelete,
            ),

            // NOTES SECTION
            RecordSection(
              key: getSectionKey(date, 'note'),
              title: 'NOTES',
              records: notes,
              date: date,
              recordType: 'note',
              onSave: onSave,
              onDelete: onDelete,
            ),
          ],
              ), // End Column
            ); // End DecoratedBox
          },
        );
      },
    );
  }
}
