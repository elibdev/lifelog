import 'journal_record.dart';

class DailyState {
  final DateTime date;
  final List<JournalRecord> records;
  final String? lastEventId;
  final bool isLoading;
  final String? error;

  DailyState({
    required this.date,
    required this.records,
    this.lastEventId,
    this.isLoading = false,
    this.error,
  });

  DailyState copyWith({
    DateTime? date,
    List<JournalRecord>? records,
    String? lastEventId,
    bool? isLoading,
    String? error,
  }) {
    return DailyState(
      date: date ?? this.date,
      records: records ?? this.records,
      lastEventId: lastEventId ?? this.lastEventId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  List<JournalRecord> get sortedRecords {
    final sorted = List<JournalRecord>.from(records);
    sorted.sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }

  bool get isEmpty => records.isEmpty && !isLoading;

  @override
  String toString() {
    return 'DailyState(date: $date, recordCount: ${records.length}, isLoading: $isLoading, error: $error)';
  }
}
