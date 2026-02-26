import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_text_field.dart';
import 'text_record_widget.dart';

/// Renders a heading record with configurable level (1, 2, or 3).
///
/// Sizes come from LifelogTheme's type scale — do not hard-code px values here.
/// - H1: headlineMedium (26px, w700) — day anchors, most prominent
/// - H2: headlineSmall (20px, w600) — sub-sections
/// - H3: titleLarge  (16px, w600)   — minor headings
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

    // Use the theme styles directly — they already encode the correct weight and
    // letter-spacing for each level. Only fall back if somehow undefined.
    final TextStyle style = switch (level) {
      1 => theme.headlineMedium ?? theme.headlineSmall!,
      2 => theme.headlineSmall ?? theme.titleLarge!,
      _ => theme.titleLarge ?? theme.bodyLarge!,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading has no semantic gutter indicator, so it gets the same
        // TypePickerButton as text records. Hidden in readOnly contexts.
        if (!readOnly)
          TypePickerButton(record: record, onSave: onSave)
        else
          const SizedBox(
            width: GridConstants.checkboxSize + GridConstants.checkboxToTextGap,
          ),
        Expanded(
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
        ),
      ],
    );
  }
}
