import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'record_text_field.dart';

/// Renders a heading record with configurable level (1, 2, or 3).
///
/// Font sizes follow Material 3 type scale with enough step between each level
/// to be visually distinct at a glance:
/// - H1: headlineMedium (28px, bold)
/// - H2: headlineSmall (24px, bold)
/// - H3: titleMedium (16px, bold)
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
        style = (theme.headlineMedium ?? theme.headlineSmall!).copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      case 2:
        style = (theme.headlineSmall ?? theme.titleLarge!).copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      default:
        style = (theme.titleMedium ?? theme.bodyLarge!).copyWith(
          fontWeight: FontWeight.bold,
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
