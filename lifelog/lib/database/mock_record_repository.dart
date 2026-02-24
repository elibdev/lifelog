import 'package:lifelog/models/record.dart';
import 'record_repository.dart';

// In-memory implementation of [RecordRepository] for Widgetbook and tests.
// No SQLite, no filesystem — just a Map that holds records by date.
// Pre-populate via the [initialData] constructor parameter.
class MockRecordRepository implements RecordRepository {
  // Dart Map literal with a type annotation: Map<K, V> inferred from usage.
  // List.from() copies lists so callers can't mutate the internal state.
  final Map<String, List<Record>> _store = {};

  MockRecordRepository({Map<String, List<Record>>? initialData}) {
    if (initialData != null) {
      for (final entry in initialData.entries) {
        // Defensive copy so caller mutations don't affect this instance.
        _store[entry.key] = List.from(entry.value);
      }
    }
  }

  @override
  Future<void> saveRecord(Record record) async {
    final list = _store.putIfAbsent(record.date, () => []);
    final index = list.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      list[index] = record;
    } else {
      list.add(record);
    }
    list.sort((a, b) => a.orderPosition.compareTo(b.orderPosition));
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    for (final list in _store.values) {
      list.removeWhere((r) => r.id == recordId);
    }
  }

  @override
  Future<List<Record>> getRecordsForDate(String date) async {
    return List.from(_store[date] ?? []);
  }

  @override
  Future<List<Record>> search(
    String query, {
    String? startDate,
    String? endDate,
  }) async {
    final q = query.toLowerCase();
    final results = <Record>[];

    for (final list in _store.values) {
      for (final record in list) {
        if (!record.content.toLowerCase().contains(q)) continue;
        if (startDate != null && record.date.compareTo(startDate) < 0) {
          continue;
        }
        if (endDate != null && record.date.compareTo(endDate) > 0) continue;
        results.add(record);
      }
    }

    // Match SqliteRecordRepository ordering: newest date first, then by position.
    results.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return a.orderPosition.compareTo(b.orderPosition);
    });

    return results;
  }
}
