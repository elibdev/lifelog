import 'package:intl/intl.dart';

// WHAT IS THIS SERVICE?
// DateService is a utility class containing all date-related logic for the app.
// It provides static methods for date calculations and formatting.
//
// WHY DOES THIS SERVICE EXIST?
// Before this refactor, date logic was scattered across multiple widgets:
//   - JournalScreen had: _getNextDate, _getPreviousDate, _formatDateForDb, _getDateForOffset
//   - DaySection had: _formatDateHeader, _isToday
//
// By centralizing date logic in one place, we:
//   1. Make date logic TESTABLE (can unit test without widgets)
//   2. Follow SINGLE RESPONSIBILITY (widgets do UI, services do logic)
//   3. Make date logic REUSABLE (any widget can use it)
//   4. Improve MAINTAINABILITY (one place to fix date bugs)
//
// WHEN TO USE SERVICES VS WIDGETS:
//   - Services: Pure logic, no UI, no state (like this)
//   - Widgets: UI rendering and user interaction
//
// STATIC METHODS:
// We use static methods because date calculations don't need instance state.
// You can call them directly: DateService.getNextDate(date)
// No need to create an instance: DateService().getNextDate(date) ❌
class DateService {
  // Private constructor prevents instantiation
  // This forces users to call static methods instead of creating instances
  // Example: DateService.getNextDate() ✅   vs   DateService().getNextDate() ❌
  DateService._();

  // ISO 8601 DATE FORMAT: "2026-01-27"
  // This is the standard format used throughout the app for:
  //   - Database storage (SQLite date comparisons work correctly)
  //   - Map keys (consistent string format)
  //   - Date calculations (DateTime.parse works with ISO format)

  /// Format a DateTime as ISO date string for database storage
  ///
  /// Converts: DateTime(2026, 1, 27) → "2026-01-27"
  ///
  /// WHY THIS FORMAT:
  /// - Lexicographical sorting matches chronological sorting ("2026-01-27" < "2026-01-28")
  /// - SQLite date functions understand this format
  /// - DateTime.parse() can parse it back to DateTime
  /// - No timezone ambiguity (we only care about dates, not times)
  static String formatForDb(DateTime date) {
    // padLeft ensures consistent width: year=4 digits, month/day=2 digits
    // Example: 2026-01-27 (not 2026-1-27)
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format a date string for display in the UI
  ///
  /// Converts: "2026-01-27" → "Mon, Jan 27, 2026"
  ///
  /// FORMAT DETAILS:
  /// - EEE: Day of week (Mon, Tue, Wed, etc.)
  /// - MMM: Month abbreviation (Jan, Feb, Mar, etc.)
  /// - d: Day of month (1-31, no leading zero)
  /// - y: Year (always 4 digits)
  ///
  /// WHY SHOW YEAR:
  /// Users can scroll infinitely into past/future, so year provides
  /// important context (especially for distant dates)
  static String formatForDisplay(String isoDate) {
    final dateTime = DateTime.parse(isoDate);
    return DateFormat('EEE, MMM d, y').format(dateTime);
  }

  /// Check if a date string represents today's date
  ///
  /// Converts: "2026-01-27" → true (if today is Jan 27, 2026)
  ///
  /// COMPARISON LOGIC:
  /// We compare year, month, and day separately (not using ==) because
  /// DateTime.now() includes hours/minutes/seconds which we don't care about.
  ///
  /// Example:
  ///   isoDate = "2026-01-27" → DateTime(2026, 1, 27, 0, 0, 0)
  ///   now = DateTime.now() → DateTime(2026, 1, 27, 14, 32, 15)
  ///   These are NOT equal, but year/month/day match → isToday = true ✅
  static bool isToday(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Get the date string for tomorrow (next day)
  ///
  /// Converts: "2026-01-27" → "2026-01-28"
  ///
  /// HANDLES MONTH/YEAR BOUNDARIES:
  /// DateTime.add handles month/year rollovers automatically:
  ///   - "2026-01-31" + 1 day → "2026-02-01" (crosses month)
  ///   - "2026-12-31" + 1 day → "2027-01-01" (crosses year)
  ///   - "2024-02-28" + 1 day → "2024-02-29" (leap year)
  static String getNextDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final nextDay = date.add(const Duration(days: 1));
    return formatForDb(nextDay);
  }

  /// Get the date string for yesterday (previous day)
  ///
  /// Converts: "2026-01-27" → "2026-01-26"
  ///
  /// HANDLES MONTH/YEAR BOUNDARIES:
  /// DateTime.subtract handles month/year rollovers automatically:
  ///   - "2026-02-01" - 1 day → "2026-01-31" (crosses month backward)
  ///   - "2027-01-01" - 1 day → "2026-12-31" (crosses year backward)
  static String getPreviousDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final prevDay = date.subtract(const Duration(days: 1));
    return formatForDb(prevDay);
  }

  /// Get a date string N days offset from today
  ///
  /// Examples:
  ///   - getDateForOffset(0) → today's date
  ///   - getDateForOffset(1) → tomorrow
  ///   - getDateForOffset(-1) → yesterday
  ///   - getDateForOffset(7) → one week from today
  ///   - getDateForOffset(-365) → one year ago
  ///
  /// USED FOR: Infinite scroll list building in JournalScreen
  /// The SliverList builder uses indices (0, 1, 2, ...) and we convert
  /// those to actual dates:
  ///   - Past list: index=0 → offset=-1 (yesterday)
  ///   - Past list: index=1 → offset=-2 (2 days ago)
  ///   - Future list: index=0 → offset=0 (today)
  ///   - Future list: index=1 → offset=1 (tomorrow)
  static String getDateForOffset(int offsetFromToday) {
    final date = DateTime.now().add(Duration(days: offsetFromToday));
    return formatForDb(date);
  }

  /// Get the current date as an ISO string
  ///
  /// Converts: DateTime.now() → "2026-01-27"
  ///
  /// USEFUL FOR:
  /// - Creating new records (record.date = DateService.today())
  /// - Default values in forms
  /// - Scroll-to-today functionality
  static String today() {
    return formatForDb(DateTime.now());
  }
}
