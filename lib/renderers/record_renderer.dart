import 'package:flutter/material.dart';
import '../models/journal_record.dart';

/// Actions that can be performed on records by renderers
class RecordActions {
  final Future<void> Function(String recordId, Map<String, dynamic> changes) updateMetadata;
  final Future<void> Function(String recordId) deleteRecord;
  final Future<void> Function(String recordId, double newPosition) reorderRecord;
  final Future<JournalRecord> Function(String recordType, double position, Map<String, dynamic> metadata) createNewRecordAfter;

  RecordActions({
    required this.updateMetadata,
    required this.deleteRecord,
    required this.reorderRecord,
    required this.createNewRecordAfter,
  });
}

/// Abstract base class for record renderers
abstract class RecordRenderer {
  /// Identifies this renderer (e.g., "note", "todo", "image")
  String get recordType;

  /// Builds the widget for displaying and editing this record type
  Widget build(
    BuildContext context,
    JournalRecord record,
    RecordActions actions,
  );

  /// Creates an empty record of this type
  JournalRecord createEmpty(DateTime date, double position);
}
