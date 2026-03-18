import 'dart:convert';

import 'package:sqlite3/common.dart';

import '../models/record.dart';
import '../models/record_link.dart';
import 'database_provider.dart';

String _previewContent(String content) {
  final first = content.trim().split('\n').first;
  return first.length > 80 ? '${first.substring(0, 80)}…' : first;
}

/// CRUD operations for records and record links.
class RecordRepository {
  Future<List<Record>> getRecordsForDatabase(String databaseId) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE database_id = :db_id ORDER BY order_position ASC',
      {':db_id': databaseId},
    );
    return results.map((row) => Record.fromJson(row)).toList();
  }

  Future<Record?> getById(String id) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM records WHERE id = :id',
      {':id': id},
    );
    if (results.isEmpty) return null;
    return Record.fromJson(results.first);
  }

  Future<void> save(Record record) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      // Capture old rowid for FTS update (INSERT OR REPLACE changes rowid)
      final oldRowidStmt =
          db.prepare('SELECT rowid FROM records WHERE id = :id');
      final oldRows = oldRowidStmt
          .selectWith(StatementParameters.named({':id': record.id}));
      final oldRowid =
          oldRows.isEmpty ? null : oldRows.first.values.first as int;
      oldRowidStmt.dispose();

      final stmt = db.prepare('''
        INSERT OR REPLACE INTO records
        (id, database_id, content, values_json, order_position, created_at, updated_at)
        VALUES (:id, :database_id, :content, :values_json, :order_position, :created_at, :updated_at)
      ''');
      stmt.executeWith(StatementParameters.named({
        ':id': record.id,
        ':database_id': record.databaseId,
        ':content': record.content,
        ':values_json': jsonEncode(record.values),
        ':order_position': record.orderPosition,
        ':created_at': record.createdAt,
        ':updated_at': record.updatedAt,
      }));
      stmt.dispose();

      // Sync FTS: remove old entry, add new one
      if (oldRowid != null) {
        final delFts =
            db.prepare('DELETE FROM records_fts WHERE rowid = :rowid');
        delFts.executeWith(StatementParameters.named({':rowid': oldRowid}));
        delFts.dispose();
      }
      final newRowid = db
          .select('SELECT last_insert_rowid()')
          .first
          .values
          .first as int;
      final insFts = db.prepare(
          'INSERT INTO records_fts(rowid, content) VALUES (:rowid, :content)');
      insFts.executeWith(StatementParameters.named(
          {':rowid': newRowid, ':content': record.content}));
      insFts.dispose();

      // Log event in same transaction — atomic with the write.
      DatabaseProvider.logEvent(
        db,
        eventType: oldRowid == null ? 'created' : 'updated',
        entityType: 'record',
        entityId: record.id,
        payload: jsonEncode({
          'database_id': record.databaseId,
          'preview': _previewContent(record.content),
        }),
      );
    });
  }

  Future<void> delete(String recordId) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      // Get rowid for FTS cleanup
      final rowidStmt =
          db.prepare('SELECT rowid FROM records WHERE id = :id');
      final rows = rowidStmt
          .selectWith(StatementParameters.named({':id': recordId}));
      if (rows.isNotEmpty) {
        final rowid = rows.first.values.first as int;
        final delFts =
            db.prepare('DELETE FROM records_fts WHERE rowid = :rowid');
        delFts.executeWith(StatementParameters.named({':rowid': rowid}));
        delFts.dispose();
      }
      rowidStmt.dispose();

      // Remove links involving this record
      final delLinks = db.prepare('''
        DELETE FROM record_links
        WHERE source_record_id = :id OR target_record_id = :id
      ''');
      delLinks.executeWith(StatementParameters.named({':id': recordId}));
      delLinks.dispose();

      final stmt = db.prepare('DELETE FROM records WHERE id = :id');
      stmt.executeWith(StatementParameters.named({':id': recordId}));
      stmt.dispose();

      DatabaseProvider.logEvent(
        db,
        eventType: 'deleted',
        entityType: 'record',
        entityId: recordId,
        payload: jsonEncode({}),
      );
    });
  }

  /// Full-text search across all databases.
  Future<List<Record>> search(String query) async {
    if (query.trim().isEmpty) return [];

    // FTS5: quote each token, join with space (implicit AND)
    final ftsQuery = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '')}"')
        .join(' ');

    final results = await DatabaseProvider.instance.queryAsync(
      '''
      SELECT records.*
      FROM records
      JOIN records_fts ON records.rowid = records_fts.rowid
      WHERE records_fts MATCH :query
      ORDER BY records.updated_at DESC
      ''',
      {':query': ftsQuery},
    );
    return results.map((row) => Record.fromJson(row)).toList();
  }

  // ---- Record Links ----

  Future<List<RecordLink>> getLinksForRecord(String recordId) async {
    final results = await DatabaseProvider.instance.queryAsync(
      '''
      SELECT * FROM record_links
      WHERE source_record_id = :id OR target_record_id = :id
      ''',
      {':id': recordId},
    );
    return results.map((row) => RecordLink.fromJson(row)).toList();
  }

  Future<void> saveLink(RecordLink link) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare('''
        INSERT OR IGNORE INTO record_links
        (source_record_id, target_record_id, field_id, created_at)
        VALUES (:source, :target, :field_id, :created_at)
      ''');
      stmt.executeWith(StatementParameters.named({
        ':source': link.sourceRecordId,
        ':target': link.targetRecordId,
        ':field_id': link.fieldId,
        ':created_at': link.createdAt,
      }));
      stmt.dispose();
    });
  }

  /// Batch-save record order positions (e.g. after drag-to-reorder).
  Future<void> updateOrder(List<Record> records) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare(
          'UPDATE records SET order_position = :pos WHERE id = :id');
      for (final record in records) {
        stmt.executeWith(StatementParameters.named({
          ':pos': record.orderPosition,
          ':id': record.id,
        }));
      }
      stmt.dispose();
    });
  }

  Future<void> deleteLink(
      String sourceId, String targetId, String fieldId) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare('''
        DELETE FROM record_links
        WHERE source_record_id = :source
          AND target_record_id = :target
          AND field_id = :field_id
      ''');
      stmt.executeWith(StatementParameters.named({
        ':source': sourceId,
        ':target': targetId,
        ':field_id': fieldId,
      }));
      stmt.dispose();
    });
  }
}
