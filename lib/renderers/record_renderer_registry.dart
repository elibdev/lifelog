import 'package:flutter/material.dart';
import '../models/journal_record.dart';
import 'record_renderer.dart';
import 'note_record_renderer.dart';
import 'todo_record_renderer.dart';

class RecordRendererRegistry {
  final Map<String, RecordRenderer> _renderers = {};

  RecordRendererRegistry();

  /// Register a renderer for a specific record type
  void register(RecordRenderer renderer) {
    _renderers[renderer.recordType] = renderer;
  }

  /// Get a renderer by record type
  RecordRenderer? getRenderer(String recordType) {
    return _renderers[recordType];
  }

  /// Build a widget for a record using the appropriate renderer
  Widget buildRecord(
    BuildContext context,
    JournalRecord record,
    RecordActions actions,
  ) {
    final renderer = getRenderer(record.recordType);
    if (renderer == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Unknown record type: ${record.recordType}',
          style: TextStyle(color: Colors.red.shade700),
        ),
      );
    }

    return renderer.build(context, record, actions);
  }

  /// Create an empty record of the specified type
  JournalRecord? createEmptyRecord(
    String recordType,
    DateTime date,
    double position,
  ) {
    final renderer = getRenderer(recordType);
    return renderer?.createEmpty(date, position);
  }

  /// Factory method to create a registry with default renderers
  static RecordRendererRegistry createDefault() {
    final registry = RecordRendererRegistry();
    registry.register(NoteRecordRenderer());
    registry.register(TodoRecordRenderer());
    return registry;
  }

  /// Get all registered record types
  List<String> get registeredTypes => _renderers.keys.toList();
}
