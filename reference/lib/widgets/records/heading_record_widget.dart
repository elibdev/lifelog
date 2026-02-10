import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog/constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a heading record with configurable level (1, 2, or 3).
///
/// Heading heights are multiples of the 24px grid:
/// - H1: 48px (bold, large)
/// - H2: 24px (bold, medium)
/// - H3: 24px (bold, normal size)
///
/// No leading widget (checkbox/bullet) — headings use full width.
class HeadingRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const HeadingRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  @override
  Widget build(BuildContext context) {
    final level = record.headingLevel.clamp(1, 3);
    final theme = Theme.of(context).textTheme;

    final TextStyle style;
    switch (level) {
      case 1:
        style = (theme.headlineSmall ?? theme.titleLarge!).copyWith(
          fontWeight: FontWeight.bold,
          height: 2.0,
        );
        break;
      case 2:
        style = (theme.titleLarge ?? theme.titleMedium!).copyWith(
          fontWeight: FontWeight.bold,
          height: GridConstants.textLineHeightMultiplier,
        );
        break;
      default:
        style = (theme.titleMedium ?? theme.bodyLarge!).copyWith(
          fontWeight: FontWeight.bold,
          height: GridConstants.textLineHeightMultiplier,
        );
    }

    return RecordTextField(
      record: record,
      onSave: onSave,
      onDelete: onDelete,
      onSubmitted: onSubmitted,
      recordIndex: recordIndex,
      onFocusNodeCreated: onFocusNodeCreated,
      onFocusNodeDisposed: onFocusNodeDisposed,
      textStyle: style,
    );
  }
}
