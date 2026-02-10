import 'dart:convert';
import 'package:sqlite3/common.dart';

import '../models/record.dart';
// Uses Event from main lib — same event sourcing pattern
import 'package:lifelog/models/event.dart';
import 'package:lifelog/database/database_provider.dart';

/// CRUD repository for records, following the same patterns as the original
/// RecordRepository but operating on the new `records` table (schema v3)
/// which stores all record types uniformly.
class RecordRepository {
  Future<void> saveRecord(Record record) async {
    final event = Event(
      eventType: EventType.recordSaved,
      recordId: record.id,
      payload: record.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO records
        (id, date, type, content, metadata, order_position, created_at, updated_at)
        VALUES (:id, :date, :type, :content, :metadata, :order_position, :created_at, :updated_at)
      ''');

      stmt.executeWith(
        StatementParameters.named({
          ':id': record.id,
          ':date': record.date,
          ':type': record.type.toDbValue(),
          ':content': record.content,
          ':metadata': jsonEncode(record.metadata),
          ':order_position': record.orderPosition,
          ':created_at': record.createdAt,
          ':updated_at': record.updatedAt,
        }),
      );
      stmt.dispose();

      // Append to event log
      final eventStmt = db.prepare('''
        INSERT INTO event_log (event_type, record_id, payload, timestamp, device_id)
        VALUES (:event_type, :record_id, :payload, :timestamp, :device_id)
      ''');
      final eventJson = event.toJson();
      eventStmt.executeWith(
        StatementParameters.named({
          ':event_type': eventJson['event_type'],
          ':record_id': eventJson['record_id'],
          ':payload': eventJson['payload'],
          ':timestamp': eventJson['timestamp'],
          ':device_id': eventJson['device_id'],
        }),
      );
      eventStmt.dispose();
    });
  }

  Future<void> deleteRecord(String recordId) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE id = :id',
      {':id': recordId},
    );

    if (results.isEmpty) return;

    final record = _parseRecordFromDb(results.first);

    final event = Event(
      eventType: EventType.recordDeleted,
      recordId: recordId,
      payload: record.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseProvider.instance.transactionAsync((db) {
      final deleteStmt = db.prepare('DELETE FROM records WHERE id = :id');
      deleteStmt.executeWith(
        StatementParameters.named({':id': recordId}),
      );
      deleteStmt.dispose();

      final eventStmt = db.prepare('''
        INSERT INTO event_log (event_type, record_id, payload, timestamp, device_id)
        VALUES (:event_type, :record_id, :payload, :timestamp, :device_id)
      ''');
      eventStmt.executeWith(
        StatementParameters.named({
          ':event_type': event.eventType.toDbValue(),
          ':record_id': event.recordId,
          ':payload': jsonEncode(event.payload),
          ':timestamp': event.timestamp,
          ':device_id': event.deviceId,
        }),
      );
      eventStmt.dispose();
    });
  }

  Future<List<Record>> getRecordsForDate(String date) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE date = :date ORDER BY order_position ASC',
      {':date': date},
    );

    return results.map(_parseRecordFromDb).toList();
  }

  /// Full-text search across record content with optional date-range filtering.
  /// Uses LIKE for simplicity (sufficient for personal journal volumes).
  Future<List<Record>> search(
    String query, {
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{':query': '%$query%'};
    final conditions = ['content LIKE :query'];

    if (startDate != null) {
      conditions.add('date >= :start');
      params[':start'] = startDate;
    }
    if (endDate != null) {
      conditions.add('date <= :end');
      params[':end'] = endDate;
    }

    final where = conditions.join(' AND ');
    final sql =
        'SELECT * FROM records WHERE $where ORDER BY date DESC, order_position ASC';

    final results = await DatabaseProvider.instance.queryAsync(sql, params);
    return results.map(_parseRecordFromDb).toList();
  }

  /// Parse a database row into a Record.
  Record _parseRecordFromDb(Map<String, Object?> row) {
    final rawMetadata = row['metadata'] as String? ?? '{}';
    final metadata = jsonDecode(rawMetadata) as Map<String, dynamic>;

    return Record(
      id: row['id'] as String,
      date: row['date'] as String,
      type: RecordType.fromDbValue(row['type'] as String),
      content: row['content'] as String? ?? '',
      metadata: metadata,
      orderPosition: (row['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
    );
  }
}
