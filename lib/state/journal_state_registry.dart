import '../database_helper.dart';
import 'daily_state_manager.dart';

class _ManagerEntry {
  final DailyStateManager manager;
  DateTime lastAccessedAt;

  _ManagerEntry({
    required this.manager,
    required this.lastAccessedAt,
  });
}

class JournalStateRegistry {
  final JournalDatabase _db;
  final Map<String, _ManagerEntry> _managers = {};
  final int maxManagers;
  final Duration cleanupDelay;

  JournalStateRegistry({
    required JournalDatabase db,
    this.maxManagers = 50,
    this.cleanupDelay = const Duration(seconds: 30),
  }) : _db = db;

  DailyStateManager getOrCreateManager(DateTime date) {
    final key = _dateKey(date);
    final now = DateTime.now();

    if (_managers.containsKey(key)) {
      // Update last accessed time
      _managers[key]!.lastAccessedAt = now;
      return _managers[key]!.manager;
    }

    // Create new manager
    final manager = DailyStateManager(date: date, db: _db);
    _managers[key] = _ManagerEntry(
      manager: manager,
      lastAccessedAt: now,
    );

    // Enforce max managers limit using LRU eviction
    _enforceLRULimit();

    // Don't auto-load - let the widget trigger loading when needed
    // This prevents 1000 simultaneous loads on app start

    return manager;
  }

  /// Clean up managers that are outside the active date window
  void cleanupOldManagers(Set<DateTime> activeDates) {
    final now = DateTime.now();
    final cutoffTime = now.subtract(cleanupDelay);
    final keysToRemove = <String>[];

    for (final entry in _managers.entries) {
      final key = entry.key;
      final managerEntry = entry.value;

      // Parse the date from the key
      final dateParts = key.split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      // Remove if not in active dates and hasn't been accessed recently
      if (!activeDates.contains(date) &&
          managerEntry.lastAccessedAt.isBefore(cutoffTime)) {
        keysToRemove.add(key);
      }
    }

    // Dispose and remove old managers
    for (final key in keysToRemove) {
      _managers[key]?.manager.dispose();
      _managers.remove(key);
    }
  }

  /// Enforce LRU limit by removing least recently used managers
  void _enforceLRULimit() {
    if (_managers.length <= maxManagers) return;

    // Sort by last accessed time and remove oldest entries
    final sortedEntries = _managers.entries.toList()
      ..sort((a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt));

    final numToRemove = _managers.length - maxManagers;
    for (int i = 0; i < numToRemove; i++) {
      final entry = sortedEntries[i];
      entry.value.manager.dispose();
      _managers.remove(entry.key);
    }
  }

  void dispose(DateTime date) {
    final key = _dateKey(date);
    final managerEntry = _managers[key];

    if (managerEntry != null) {
      managerEntry.manager.dispose();
      _managers.remove(key);
    }
  }

  void disposeAll() {
    for (final entry in _managers.values) {
      entry.manager.dispose();
    }
    _managers.clear();
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  int get managersCount => _managers.length;
}
