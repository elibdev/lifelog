import 'dart:convert';
import 'package:sqlite3/common.dart';

import '../models/record.dart';
import '../models/event.dart';
import 'database_provider.dart';

class RecordRepository {
  Future<void> saveRecord(Record record) async {
    final event = Event(
      eventType: EventType.recordSaved,
      recordId: record.id,
      payload: record.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Atomic transaction: update records + log event
    await DatabaseProvider.instance.transactionAsync((db) {
      // INSERT OR REPLACE using named parameters
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO records
        (id, date, type, metadata, created_at, updated_at, order_position)
        VALUES (:id, :date, :type, :metadata, :created_at, :updated_at, :order_position)
      ''');

      // Hey Claude Do you see how I did this with name parameters? Do this for all the statements.
      stmt.executeWith(
        StatementParameters.named({
          ':id': record.id,
          ':date': record.date,
          ':type': record.type,
          ':metadata': jsonEncode({
            'content': record.content,
            if (record is TodoRecord) 'checked': record.checked,
          }),
          ':created_at': record.createdAt,
          ':updated_at': record.updatedAt,
          ':order_position': record.orderPosition,
        }),
      );
      stmt.dispose();

      // Append to event_log
      final eventStmt = db.prepare('''
        INSERT INTO event_log (event_type, record_id, payload, timestamp, device_id)
        VALUES (:event_type, :record_id, :payload, :timestamp, :device_id)
      ''');
      final eventJson = event.toJson();
      eventStmt.execute([
        eventJson['event_type'],
        eventJson['record_id'],
        eventJson['payload'],
        eventJson['timestamp'],
        eventJson['device_id'],
      ]);
      eventStmt.dispose();
    });
  }

  Future<void> deleteRecord(String recordId) async {
    // Get record before deletion
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE id = :id',
      {'id': recordId},
    );

    if (results.isEmpty) return;

    final recordJson = _parseRecordFromDb(results.first);
    final record = Record.fromJson(recordJson);

    final event = Event(
      eventType: EventType.recordDeleted,
      recordId: recordId,
      payload: record.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      deviceId: null,
    );

    await DatabaseProvider.instance.transactionAsync((db) {
      final deleteStmt = db.prepare('DELETE FROM records WHERE id = :id');
      deleteStmt.execute([recordId]);
      deleteStmt.dispose();

      final eventStmt = db.prepare('''
        INSERT INTO event_log (event_type, record_id, payload, timestamp, device_id)
        VALUES (:event_type, :record_id, :payload, :timestamp, :device_id)
      ''');
      eventStmt.execute([
        event.eventType.toDbValue(),
        event.recordId,
        jsonEncode(event.payload),
        event.timestamp,
        event.deviceId,
      ]);
      eventStmt.dispose();
    });
  }

  Future<List<Record>> getRecordsForDate(String date) async {
    // Claude, is there no better way of doing this with selectWith or iterateWith?
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE date = :date ORDER BY order_position ASC',
      {'date': date},
    );

    return results.map((row) {
      final json = _parseRecordFromDb(row);
      return Record.fromJson(json);
    }).toList();
  }

  Future<List<Record>> getRecordsForDateRange(
    String startDate,
    String endDate,
  ) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE date >= :start AND date <= :end ORDER BY date ASC, order_position ASC',
      {'start': startDate, 'end': endDate},
    );

    return results.map((row) {
      final json = _parseRecordFromDb(row);
      return Record.fromJson(json);
    }).toList();
  }

  // Helper to parse DB row into Record JSON format
  Map<String, dynamic> _parseRecordFromDb(Map<String, Object?> row) {
    final metadata =
        jsonDecode(row['metadata'] as String) as Map<String, dynamic>;
    return {
      'id': row['id'],
      'date': row['date'],
      'type': row['type'],
      'metadata': metadata,
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'order_position': row['order_position'],
    };
  }
}
