import 'dart:convert';

import 'package:sqlite3/common.dart';

import '../models/field.dart';
import 'database_provider.dart';

/// CRUD operations for schema fields.
class FieldRepository {
  Future<List<Field>> getFieldsForDatabase(String databaseId) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM fields WHERE database_id = :db_id ORDER BY order_position ASC',
      {':db_id': databaseId},
    );
    return results.map((row) => Field.fromJson(row)).toList();
  }

  Future<void> save(Field field) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO fields
        (id, database_id, name, field_type, config, order_position, created_at, updated_at)
        VALUES (:id, :database_id, :name, :field_type, :config, :order_position, :created_at, :updated_at)
      ''');
      stmt.executeWith(StatementParameters.named({
        ':id': field.id,
        ':database_id': field.databaseId,
        ':name': field.name,
        ':field_type': field.fieldType.toDbValue(),
        ':config': jsonEncode(field.config),
        ':order_position': field.orderPosition,
        ':created_at': field.createdAt,
        ':updated_at': field.updatedAt,
      }));
      stmt.dispose();
    });
  }

  Future<void> delete(String fieldId) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      // Remove links created by this relation field
      final delLinks =
          db.prepare('DELETE FROM record_links WHERE field_id = :id');
      delLinks.executeWith(StatementParameters.named({':id': fieldId}));
      delLinks.dispose();

      final stmt = db.prepare('DELETE FROM fields WHERE id = :id');
      stmt.executeWith(StatementParameters.named({':id': fieldId}));
      stmt.dispose();
    });
  }

  /// Batch-save field order positions (e.g. after drag-to-reorder).
  Future<void> updateOrder(List<Field> fields) async {
    await DatabaseProvider.instance.transactionAsync((db) {
      final stmt = db.prepare(
          'UPDATE fields SET order_position = :pos WHERE id = :id');
      for (final field in fields) {
        stmt.executeWith(StatementParameters.named({
          ':pos': field.orderPosition,
          ':id': field.id,
        }));
      }
      stmt.dispose();
    });
  }
}
