import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../models/daily_state.dart';
import '../models/journal_record.dart';
import '../models/journal_event.dart';

class DailyStateManager extends ChangeNotifier {
  final DateTime date;
  final JournalDatabase _db;
  DailyState _state;

  static const _uuid = Uuid();

  DailyStateManager({
    required this.date,
    required JournalDatabase db,
  })  : _db = db,
        _state = DailyState(date: date, records: []);

  DailyState get state => _state;

  bool get isLoaded => _state.records.isNotEmpty || _state.error != null;

  Future<void> load() async {
    // Don't show loading state - just silently load in background
    try {
      // Try to load from snapshot first
      final snapshot = await _db.getSnapshot(date);
      if (snapshot != null) {
        _state = DailyState(
          date: date,
          records: snapshot['records'] as List<JournalRecord>,
          lastEventId: snapshot['last_event_id'] as String,
          isLoading: false,
        );
      } else {
        // Load from records table
        final records = await _db.getRecordsForDate(date);
        _state = DailyState(
          date: date,
          records: records,
          isLoading: false,
        );
      }
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  /// Load state from batch query results
  void loadFromBatch(List<JournalRecord> records) {
    if (isLoaded) return; // Already loaded

    _state = DailyState(
      date: date,
      records: records,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<JournalRecord> createRecord(
    String recordType,
    double position,
    Map<String, dynamic> metadata,
  ) async {
    final now = DateTime.now();
    final recordId = 'rec_${_uuid.v4()}';

    final record = JournalRecord(
      id: recordId,
      date: date,
      recordType: recordType,
      position: position,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.recordCreated,
      recordId: recordId,
      date: date,
      timestamp: now,
      payload: {
        'record_type': recordType,
        'position': position,
        'metadata': metadata,
      },
    );

    // Optimistic update
    final updatedRecords = [..._state.records, record];
    _state = _state.copyWith(records: updatedRecords);
    notifyListeners();

    try {
      await _db.createRecord(record, event);
      return record;
    } catch (e) {
      // Rollback on error
      _state = _state.copyWith(
        records: _state.records.where((r) => r.id != recordId).toList(),
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateMetadata(
    String recordId,
    Map<String, dynamic> changes,
  ) async {
    final recordIndex = _state.records.indexWhere((r) => r.id == recordId);
    if (recordIndex == -1) return;

    final oldRecord = _state.records[recordIndex];
    final newMetadata = {...oldRecord.metadata, ...changes};
    final now = DateTime.now();

    final updatedRecord = oldRecord.copyWith(
      metadata: newMetadata,
      updatedAt: now,
    );

    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.metadataUpdated,
      recordId: recordId,
      date: date,
      timestamp: now,
      payload: {
        'changes': changes,
        'previous': oldRecord.metadata,
      },
    );

    // Optimistic update
    final updatedRecords = List<JournalRecord>.from(_state.records);
    updatedRecords[recordIndex] = updatedRecord;
    _state = _state.copyWith(records: updatedRecords);
    notifyListeners();

    try {
      await _db.updateRecord(updatedRecord, event);
    } catch (e) {
      // Rollback on error
      final rollbackRecords = List<JournalRecord>.from(_state.records);
      rollbackRecords[recordIndex] = oldRecord;
      _state = _state.copyWith(
        records: rollbackRecords,
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteRecord(String recordId) async {
    final recordIndex = _state.records.indexWhere((r) => r.id == recordId);
    if (recordIndex == -1) return;

    final deletedRecord = _state.records[recordIndex];
    final now = DateTime.now();

    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.recordDeleted,
      recordId: recordId,
      date: date,
      timestamp: now,
      payload: {
        'deleted_record': {
          'record_type': deletedRecord.recordType,
          'position': deletedRecord.position,
          'metadata': deletedRecord.metadata,
        },
      },
    );

    // Optimistic update
    final updatedRecords = _state.records.where((r) => r.id != recordId).toList();
    _state = _state.copyWith(records: updatedRecords);
    notifyListeners();

    try {
      await _db.deleteRecord(recordId, event);
    } catch (e) {
      // Rollback on error
      final rollbackRecords = [..._state.records, deletedRecord];
      _state = _state.copyWith(
        records: rollbackRecords,
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderRecord(String recordId, double newPosition) async {
    final recordIndex = _state.records.indexWhere((r) => r.id == recordId);
    if (recordIndex == -1) return;

    final oldRecord = _state.records[recordIndex];
    final now = DateTime.now();

    final updatedRecord = oldRecord.copyWith(
      position: newPosition,
      updatedAt: now,
    );

    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.recordReordered,
      recordId: recordId,
      date: date,
      timestamp: now,
      payload: {
        'old_position': oldRecord.position,
        'new_position': newPosition,
      },
    );

    // Optimistic update
    final updatedRecords = List<JournalRecord>.from(_state.records);
    updatedRecords[recordIndex] = updatedRecord;
    _state = _state.copyWith(records: updatedRecords);
    notifyListeners();

    try {
      await _db.updateRecord(updatedRecord, event);
    } catch (e) {
      // Rollback on error
      final rollbackRecords = List<JournalRecord>.from(_state.records);
      rollbackRecords[recordIndex] = oldRecord;
      _state = _state.copyWith(
        records: rollbackRecords,
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  double calculateNewPosition({JournalRecord? after, JournalRecord? before}) {
    if (after == null && before == null) {
      // First record
      return 1.0;
    } else if (after == null) {
      // Insert at beginning
      return before!.position / 2;
    } else if (before == null) {
      // Insert at end
      return after.position + 1.0;
    } else {
      // Insert between two records
      return (after.position + before.position) / 2;
    }
  }
}
