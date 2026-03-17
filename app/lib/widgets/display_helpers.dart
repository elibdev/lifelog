import 'package:flutter/material.dart';

/// Semantic color pairs for select option badges, indexed by position in the
/// options list. Users typically order options from most positive (index 0) to
/// most negative. Light and dark variants keep badges readable on any surface.
const _lightSelectColors = [
  (bg: Color(0xFFDCFCE7), fg: Color(0xFF166534)), // Green — positive
  (bg: Color(0xFFDBEAFE), fg: Color(0xFF1E40AF)), // Blue — neutral-positive
  (bg: Color(0xFFFEF9C3), fg: Color(0xFF854D0E)), // Amber — neutral
  (bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B)), // Red — negative
];

const _darkSelectColors = [
  (bg: Color(0xFF14532D), fg: Color(0xFF86EFAC)), // Green
  (bg: Color(0xFF1E3A5F), fg: Color(0xFF93C5FD)), // Blue
  (bg: Color(0xFF713F12), fg: Color(0xFFFDE68A)), // Amber
  (bg: Color(0xFF7F1D1D), fg: Color(0xFFFCA5A5)), // Red
];

/// Returns background and foreground colors for a select option badge based on
/// its position in the options list. Falls back to theme defaults for options
/// beyond the 4th position.
({Color bg, Color fg}) selectOptionColors({
  required String value,
  required List<String> options,
  required ColorScheme colorScheme,
}) {
  final index = options.indexOf(value);
  final palette = colorScheme.brightness == Brightness.dark
      ? _darkSelectColors
      : _lightSelectColors;
  if (index >= 0 && index < palette.length) {
    return palette[index];
  }
  return (bg: colorScheme.primaryContainer, fg: colorScheme.onPrimaryContainer);
}

/// Format a record's timestamp as a short date string: "Mar 5".
/// Returns empty string for epoch 0 (unset timestamps).
/// Uses UTC to match the UTC-based timestamps stored in the DB — avoids
/// timezone drift between where records are created and displayed.
String formatRecordDate(int timestampMs) {
  if (timestampMs == 0) return '';
  // isUtc: true — timestamps are UTC epoch millis; interpret as UTC date
  // so "Mar 5" is stable regardless of device/CI timezone.
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
