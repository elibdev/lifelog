import 'package:flutter/material.dart';

/// Manages focus navigation between journal records across dates
class JournalFocusManager {
  // Map of record ID to FocusNode
  final Map<String, FocusNode> _recordFocusNodes = {};

  // Ordered list of record IDs by date and position
  // Structure: {date: [recordId1, recordId2, ...]}
  final Map<DateTime, List<String>> _dateRecordOrder = {};

  // Sorted list of dates (cached)
  List<DateTime>? _sortedDates;

  /// Register a record's focus node
  void registerRecord(String recordId, DateTime date, FocusNode node) {
    _recordFocusNodes[recordId] = node;

    // Normalize date to midnight
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Add to date order
    _dateRecordOrder.putIfAbsent(normalizedDate, () => []);
    if (!_dateRecordOrder[normalizedDate]!.contains(recordId)) {
      _dateRecordOrder[normalizedDate]!.add(recordId);
    }

    // Invalidate sorted dates cache
    _sortedDates = null;
  }

  /// Unregister a record's focus node
  void unregisterRecord(String recordId, DateTime date) {
    _recordFocusNodes.remove(recordId);

    // Normalize date
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Remove from date order
    _dateRecordOrder[normalizedDate]?.remove(recordId);
    if (_dateRecordOrder[normalizedDate]?.isEmpty ?? false) {
      _dateRecordOrder.remove(normalizedDate);
    }

    // Invalidate sorted dates cache
    _sortedDates = null;
  }

  /// Update the order of records for a specific date
  void updateDateOrder(DateTime date, List<String> recordIds) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _dateRecordOrder[normalizedDate] = recordIds;
    _sortedDates = null;
  }

  /// Move focus to the previous record
  bool moveToPrevious(String currentRecordId) {
    final previousId = _findPreviousRecordId(currentRecordId);
    if (previousId == null) return false;

    final previousNode = _recordFocusNodes[previousId];
    if (previousNode != null) {
      previousNode.requestFocus();
      return true;
    }
    return false;
  }

  /// Move focus to the next record
  bool moveToNext(String currentRecordId) {
    final nextId = _findNextRecordId(currentRecordId);
    if (nextId == null) return false;

    final nextNode = _recordFocusNodes[nextId];
    if (nextNode != null) {
      nextNode.requestFocus();
      return true;
    }
    return false;
  }

  /// Find the previous record ID
  String? _findPreviousRecordId(String currentRecordId) {
    // Find which date contains this record
    DateTime? currentDate;
    int? currentIndex;

    for (final entry in _dateRecordOrder.entries) {
      final index = entry.value.indexOf(currentRecordId);
      if (index != -1) {
        currentDate = entry.key;
        currentIndex = index;
        break;
      }
    }

    if (currentDate == null || currentIndex == null) return null;

    // If not first in date, return previous in same date
    if (currentIndex > 0) {
      return _dateRecordOrder[currentDate]![currentIndex - 1];
    }

    // Otherwise, get last record from previous date
    final sortedDates = _getSortedDates();
    final currentDateIndex = sortedDates.indexOf(currentDate);
    if (currentDateIndex <= 0) return null; // No previous date

    // Find the previous date that has records
    for (int i = currentDateIndex - 1; i >= 0; i--) {
      final previousDate = sortedDates[i];
      final records = _dateRecordOrder[previousDate];
      if (records != null && records.isNotEmpty) {
        return records.last;
      }
    }

    return null;
  }

  /// Find the next record ID
  String? _findNextRecordId(String currentRecordId) {
    // Find which date contains this record
    DateTime? currentDate;
    int? currentIndex;

    for (final entry in _dateRecordOrder.entries) {
      final index = entry.value.indexOf(currentRecordId);
      if (index != -1) {
        currentDate = entry.key;
        currentIndex = index;
        break;
      }
    }

    if (currentDate == null || currentIndex == null) return null;

    final currentDateRecords = _dateRecordOrder[currentDate]!;

    // If not last in date, return next in same date
    if (currentIndex < currentDateRecords.length - 1) {
      return currentDateRecords[currentIndex + 1];
    }

    // Otherwise, get first record from next date
    final sortedDates = _getSortedDates();
    final currentDateIndex = sortedDates.indexOf(currentDate);
    if (currentDateIndex == -1 || currentDateIndex >= sortedDates.length - 1) {
      return null; // No next date
    }

    // Find the next date that has records
    for (int i = currentDateIndex + 1; i < sortedDates.length; i++) {
      final nextDate = sortedDates[i];
      final records = _dateRecordOrder[nextDate];
      if (records != null && records.isNotEmpty) {
        return records.first;
      }
    }

    return null;
  }

  /// Get sorted list of dates
  List<DateTime> _getSortedDates() {
    _sortedDates ??= _dateRecordOrder.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    return _sortedDates!;
  }

  /// Dispose all resources
  void dispose() {
    _recordFocusNodes.clear();
    _dateRecordOrder.clear();
    _sortedDates = null;
  }
}
