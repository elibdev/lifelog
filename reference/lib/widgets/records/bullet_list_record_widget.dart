import 'package:flutter/material.dart';
import '../../models/record.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'record_text_field.dart';

/// Renders a bulleted list item with indent support.
///
/// Indent level controls left padding: each level adds one grid spacing (24px).
/// The bullet character changes by level for visual hierarchy.
class BulletListRecordWidget extends StatelessWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)? onSubmitted;
  final int? recordIndex;
  final void Function(int, String, FocusNode)? onFocusNodeCreated;
  final void Function(String)? onFocusNodeDisposed;

  final bool readOnly;

  const BulletListRecordWidget({
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

  String _bulletForLevel(int level) {
    // ◦ (U+25E6), ▪ (U+25AA), and ○ (U+25CB) are absent from the Flutter SDK's
    // Roboto subset bundled for tests. Use characters from Basic Latin / Latin-1
    // Supplement which are guaranteed to be present in any Latin font.
    const bullets = ['•', '–', '·'];
    return bullets[level.clamp(0, bullets.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final indentLevel = record.indentLevel;

    return Padding(
      padding: EdgeInsets.only(
        left: indentLevel * GridConstants.spacing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(right: GridConstants.checkboxToTextGap),
            child: SizedBox(
              width: GridConstants.checkboxSize,
              child: Text(
                _bulletForLevel(indentLevel),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              readOnly: readOnly,
            ),
          ),
        ],
      ),
    );
  }
}
