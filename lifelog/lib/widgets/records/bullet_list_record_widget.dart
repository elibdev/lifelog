import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../../constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a bulleted list item with indent support.
///
/// Each indent level adds one [GridConstants.indentStep] (24px) of left
/// padding. Bullet characters change per level for visual hierarchy:
/// - Level 0: filled circle (•)
/// - Level 1: en-dash (–)
/// - Level 2: middle dot (·)
class BulletListRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  const BulletListRecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  /// Bullet character varies by indent level for visual hierarchy.
  /// Uses Basic Latin / Latin-1 characters guaranteed in Roboto.
  String _bulletForLevel(int level) {
    const bullets = ['•', '–', '·'];
    return bullets[level.clamp(0, bullets.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indentLevel = record.indentLevel;

    return Padding(
      padding: EdgeInsets.only(
        left: indentLevel * GridConstants.indentStep,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
            child: SizedBox(
              width: GridConstants.checkboxSize,
              height: GridConstants.rowHeight,
              child: Center(
                child: Text(
                  _bulletForLevel(indentLevel),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
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
            ),
          ),
        ],
      ),
    );
  }
}
