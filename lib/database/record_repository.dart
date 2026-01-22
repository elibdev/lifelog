import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/record.dart';
import '../models/event.dart';
import 'database_provider.dart';

class RecordRepository {
  Future<void> saveRecord(Record record, {bool isNew = false}) async {
    final db = await DatabaseProvider.instance.database;

    // Prepare event
    final event = Event(
      eventType: isNew ? EventType.recordCreated : EventType.recordUpdated,
      recordId: record.id,
      payload: record.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      deviceId: null, // TODO: Add device ID if needed for multi-device sync
    );

    // Atomic transaction: update records + log event
    await db.transaction((txn) async {
      // Upsert to records table
      await txn.insert(
        'records',
        {
          'id': record.id,
          'date': record.date,
          'type': record.type,
          'metadata': jsonEncode({
            'content': record.content,
            if (record is TodoRecord) 'checked': record.checked,
          }),
          'created_at': record.createdAt,
          'updated_at': record.updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Append to event_log
      await txn.insert('event_log', event.toJson());
    });
  }

  Future<void> deleteRecord(String recordId) async {
    final db = await DatabaseProvider.instance.database;

    // Get the record before deletion for event payload
    final results = await db.query(
      'records',
      where: 'id = ?',
      whereArgs: [recordId],
    );

    if (results.isEmpty) return;

    final recordJson = _parseRecordFromDb(results.first);
    final record = Record.fromJson(recordJson);

    // Prepare deletion event
    final event = Event(
      eventType: EventType.recordDeleted,
      recordId: recordId,
      payload: record.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      deviceId: null,
    );

    // Atomic transaction: delete from records + log event
    await db.transaction((txn) async {
      await txn.delete('records', where: 'id = ?', whereArgs: [recordId]);
      await txn.insert('event_log', event.toJson());
    });
  }

  Future<List<Record>> getRecordsForDate(String date) async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      'records',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at ASC',
    );

    return results.map((row) {
      final json = _parseRecordFromDb(row);
      return Record.fromJson(json);
    }).toList();
  }

  Future<List<Record>> getRecordsForDateRange(String startDate, String endDate) async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      'records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, created_at ASC',
    );

    return results.map((row) {
      final json = _parseRecordFromDb(row);
      return Record.fromJson(json);
    }).toList();
  }

  // Helper to parse DB row into Record JSON format
  Map<String, dynamic> _parseRecordFromDb(Map<String, dynamic> row) {
    final metadata = jsonDecode(row['metadata'] as String) as Map<String, dynamic>;
    return {
      'id': row['id'],
      'date': row['date'],
      'type': row['type'],
      'metadata': metadata,
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    };
  }
}
