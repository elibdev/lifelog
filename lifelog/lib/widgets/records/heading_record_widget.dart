import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'record_text_field.dart';

/// Renders a heading record with configurable level (1, 2, or 3).
///
/// Swiss typographic hierarchy — each level has a distinct size, weight,
/// and letter-spacing to be immediately recognizable:
/// - H1: 26px, bold, tight tracking — section anchors
/// - H2: 20px, semibold — sub-sections
/// - H3: 16px, semibold — minor headings
class HeadingRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;
  final bool readOnly;

  const HeadingRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final level = record.headingLevel.clamp(1, 3);
    final theme = Theme.of(context).textTheme;

    // Each heading level maps to a specific TextTheme style from our
    // design system, ensuring consistent hierarchy across the app.
    final TextStyle style = switch (level) {
      1 => theme.headlineMedium!,
      2 => theme.headlineSmall!,
      _ => theme.titleLarge!,
    };

    return Padding(
      // Headings get top breathing room — separates them from content above
      padding: EdgeInsets.only(top: level == 1 ? 4.0 : 2.0),
      child: RecordTextField(
        record: record,
        onSave: onSave,
        onDelete: onDelete,
        onSubmitted: onSubmitted,
        recordIndex: recordIndex,
        onFocusNodeCreated: onFocusNodeCreated,
        onFocusNodeDisposed: onFocusNodeDisposed,
        textStyle: style,
        readOnly: readOnly,
      ),
    );
  }
}
