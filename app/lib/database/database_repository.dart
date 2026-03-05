import 'dart:convert';

import 'package:sqlite3/common.dart';

import '../models/app_database.dart';
import 'database_provider.dart';

/// CRUD operations for user-created databases.
class DatabaseRepository {
  Future<List<AppDatabase>> getAll() async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM databases ORDER BY order_position ASC',
      {},
    );
    return results.map((row) => AppDatabase.fromJson(row)).toList();
  }

  Future<AppDatabase?> getById(String id) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM databases WHERE id = :id',
      {':id': id},
    );
    if (results.isEmpty) return null;
    return AppDatabase.fromJson(results.first);
  }

  Future<void> save(AppDatabase database) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO databases
        (id, name, config, order_position, created_at, updated_at)
        VALUES (:id, :name, :config, :order_position, :created_at, :updated_at)
      ''');
      stmt.executeWith(StatementParameters.named({
        ':id': database.id,
        ':name': database.name,
        ':config': jsonEncode(database.config),
        ':order_position': database.orderPosition,
        ':created_at': database.createdAt,
        ':updated_at': database.updatedAt,
      }));
      stmt.dispose();
    });
  }

  Future<void> delete(String id) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      // Delete linked records' FTS entries, links, records, fields, then database.
      // Order matters for referential integrity.
      db.execute('''
        DELETE FROM records_fts WHERE rowid IN (
          SELECT rowid FROM records WHERE database_id = '$id'
        )
      ''');
      db.execute('''
        DELETE FROM record_links WHERE source_record_id IN (
          SELECT id FROM records WHERE database_id = '$id'
        ) OR target_record_id IN (
          SELECT id FROM records WHERE database_id = '$id'
        )
      ''');

      final stmts = [
        "DELETE FROM records WHERE database_id = :id",
        "DELETE FROM fields WHERE database_id = :id",
        "DELETE FROM databases WHERE id = :id",
      ];
      for (final sql in stmts) {
        final stmt = db.prepare(sql);
        stmt.executeWith(StatementParameters.named({':id': id}));
        stmt.dispose();
      }
    });
  }
}
