import 'dart:convert';
import 'package:sqlite3/common.dart';

import '../models/record.dart';
// Uses Event from main lib — same event sourcing pattern
import 'package:lifelog_reference/models/event.dart';
import 'package:lifelog_reference/database/database_provider.dart';

// Dart abstract classes define a contract without implementation.
// Screens depend on this interface, not the SQLite or mock concrete classes —
// the classic Dependency Inversion Principle, which also makes Widgetbook possible.
// See: https://dart.dev/language/class-modifiers#abstract
abstract class RecordRepository {
  Future<void> saveRecord(Record record);
  Future<void> deleteRecord(String recordId);
  Future<List<Record>> getRecordsForDate(String date);
  Future<List<Record>> search(
    String query, {
    String? startDate,
    String? endDate,
  });
}

/// SQLite-backed implementation of [RecordRepository].
/// Uses [DatabaseProvider] for WAL-mode SQLite with Isolate-backed async queries.
class SqliteRecordRepository implements RecordRepository {
  @override
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

  @override
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

  @override
  Future<List<Record>> getRecordsForDate(String date) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE date = :date ORDER BY order_position ASC',
      {':date': date},
    );

    return results.map(_parseRecordFromDb).toList();
  }

  @override
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
