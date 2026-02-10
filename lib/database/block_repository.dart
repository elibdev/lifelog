import 'dart:convert';
import 'package:sqlite3/common.dart';

import '../models/block.dart';
import '../models/event.dart';
import 'database_provider.dart';

/// CRUD repository for blocks, following the same patterns as RecordRepository.
///
/// Uses atomic transactions (upsert + event log) for every write operation
/// to maintain the event sourcing architecture.
class BlockRepository {
  Future<void> saveBlock(Block block) async {
    final event = Event(
      eventType: EventType.recordSaved,
      recordId: block.id,
      payload: block.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO blocks
        (id, date, type, content, metadata, order_position, created_at, updated_at)
        VALUES (:id, :date, :type, :content, :metadata, :order_position, :created_at, :updated_at)
      ''');

      stmt.executeWith(
        StatementParameters.named({
          ':id': block.id,
          ':date': block.date,
          ':type': block.type.toDbValue(),
          ':content': block.content,
          ':metadata': jsonEncode(block.metadata),
          ':order_position': block.orderPosition,
          ':created_at': block.createdAt,
          ':updated_at': block.updatedAt,
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

  Future<void> deleteBlock(String blockId) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM blocks WHERE id = :id',
      {':id': blockId},
    );

    if (results.isEmpty) return;

    final block = _parseBlockFromDb(results.first);

    final event = Event(
      eventType: EventType.recordDeleted,
      recordId: blockId,
      payload: block.toJson(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseProvider.instance.transactionAsync((db) {
      final deleteStmt = db.prepare('DELETE FROM blocks WHERE id = :id');
      deleteStmt.executeWith(
        StatementParameters.named({':id': blockId}),
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

  Future<List<Block>> getBlocksForDate(String date) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM blocks WHERE date = :date ORDER BY order_position ASC',
      {':date': date},
    );

    return results.map(_parseBlockFromDb).toList();
  }

  /// Full-text search across block content with optional date-range filtering.
  /// Uses LIKE for simplicity (sufficient for personal journal volumes).
  Future<List<Block>> search(
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
        'SELECT * FROM blocks WHERE $where ORDER BY date DESC, order_position ASC';

    final results = await DatabaseProvider.instance.queryAsync(sql, params);
    return results.map(_parseBlockFromDb).toList();
  }

  /// Parse a database row into a Block.
  Block _parseBlockFromDb(Map<String, Object?> row) {
    final rawMetadata = row['metadata'] as String? ?? '{}';
    final metadata = jsonDecode(rawMetadata) as Map<String, dynamic>;

    return Block(
      id: row['id'] as String,
      date: row['date'] as String,
      type: BlockType.fromDbValue(row['type'] as String),
      content: row['content'] as String? ?? '',
      metadata: metadata,
      orderPosition: (row['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
    );
  }
}
