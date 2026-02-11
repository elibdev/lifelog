import 'package:intl/intl.dart';

/// Static utility for date operations.
///
/// All dates are ISO 8601 strings ('2026-02-11'), NOT DateTime objects.
/// This keeps the domain layer serialization-friendly and avoids timezone bugs.
class DateService {
  DateService._();

  static final DateFormat _displayFormat = DateFormat('EEEE, MMMM d');

  /// Whether [dateString] is today's date.
  static bool isToday(String dateString) {
    return dateString == today();
  }

  /// Format for display: '2026-02-11' -> 'Tuesday, February 11'
  static String formatForDisplay(String dateString) {
    final date = DateTime.parse(dateString);
    return _displayFormat.format(date);
  }

  /// Today's date as an ISO string.
  static String today() {
    final now = DateTime.now();
    return _isoDate(now);
  }

  /// Date offset from today: negative = past, positive = future.
  static String getDateForOffset(int daysOffset) {
    final date = DateTime.now().add(Duration(days: daysOffset));
    return _isoDate(date);
  }

  /// The day after [dateString].
  static String getNextDate(String dateString) {
    final date = DateTime.parse(dateString).add(const Duration(days: 1));
    return _isoDate(date);
  }

  /// The day before [dateString].
  static String getPreviousDate(String dateString) {
    final date = DateTime.parse(dateString).subtract(const Duration(days: 1));
    return _isoDate(date);
  }

  static String _isoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
