import 'package:flutter/material.dart';

/// Layout constants for the dotted-grid journal design.
///
/// Every vertical measurement is a multiple of [spacing] (24 px),
/// giving the journal a ruled-notebook feel.
class GridConstants {
  GridConstants._();

  /// Base grid spacing — all vertical dimensions are multiples of this.
  static const double spacing = 24.0;

  /// Line-height multiplier for body text so baselines land on grid lines.
  static const double textLineHeightMultiplier = 1.0;

  /// Dot color for the grid background in light mode.
  static const Color dotColorLight = Color(0xFFE0E0E0);

  /// Dot color for the grid background in dark mode.
  static const Color dotColorDark = Color(0xFF333333);

  /// Padding above a day-section header.
  static const double sectionTopPadding = 16.0;

  /// Padding below a day-section header.
  static const double sectionHeaderBottomPadding = 8.0;

  /// Vertical spacing between record items.
  static const double itemVerticalSpacing = 0.0;

  /// Checkbox / leading-icon size.
  static const double checkboxSize = 24.0;

  /// Gap between checkbox and text.
  static const double checkboxToTextGap = 12.0;

  /// Responsive left padding: wider screens get more margin.
  static double calculateContentLeftPadding(double screenWidth) {
    if (screenWidth > 900) return 64.0;
    if (screenWidth >= 600) return 40.0;
    return 16.0;
  }

  /// Responsive right padding (mirrors left).
  static double calculateContentRightPadding(double screenWidth) {
    if (screenWidth > 900) return 64.0;
    if (screenWidth >= 600) return 40.0;
    return 16.0;
  }

  /// Horizontal offset for dotted-grid lines, aligned to content padding.
  static double calculateGridOffset(double screenWidth) {
    return calculateContentLeftPadding(screenWidth);
  }
}
