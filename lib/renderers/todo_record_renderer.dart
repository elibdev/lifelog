import 'package:flutter/material.dart';
import '../models/journal_record.dart';
import 'record_renderer.dart';

class TodoRecordRenderer extends RecordRenderer {
  @override
  String get recordType => 'todo';

  @override
  Widget build(
    BuildContext context,
    JournalRecord record,
    RecordActions actions,
  ) {
    return TodoRecordWidget(
      record: record,
      actions: actions,
    );
  }

  @override
  JournalRecord createEmpty(DateTime date, double position) {
    return JournalRecord(
      id: '', // Will be set by state manager
      date: date,
      recordType: 'todo',
      position: position,
      metadata: {'content': '', 'checked': false},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class TodoRecordWidget extends StatelessWidget {
  final JournalRecord record;
  final RecordActions actions;

  const TodoRecordWidget({
    super.key,
    required this.record,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final content = record.metadata['content'] as String? ?? '';
    final checked = record.metadata['checked'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox (replaces bullet)
          Padding(
            padding: const EdgeInsets.only(top: 2.0, right: 6.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: checked,
                onChanged: (value) {
                  actions.updateMetadata(
                    record.id,
                    {'checked': value ?? false},
                  );
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Color(0xFF8B7355), width: 1.5),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF8B7355);
                  }
                  return Colors.transparent;
                }),
              ),
            ),
          ),
          // Todo content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: checked ? TextDecoration.lineThrough : null,
                  color: checked ? const Color(0xFFB8A896) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
