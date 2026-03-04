/// Layout constants for the journal design.
///
/// Every vertical measurement is a multiple of [spacing] (24 px).
class GridConstants {
  GridConstants._();

  /// Base grid spacing — all vertical dimensions are multiples of this.
  static const double spacing = 24.0;

  /// Minimum record row height — ensures consistent vertical rhythm.
  static const double rowHeight = 28.0;

  /// Indent step for bullet list nesting.
  static const double indentStep = 24.0;

  /// Line-height multiplier for body text. 1.5 gives comfortable reading
  /// rhythm for journal-style content (matches the production lifelog package).
  static const double textLineHeightMultiplier = 1.5;

  /// Padding above a day-section header.
  static const double sectionTopPadding = 16.0;

  /// Padding below a day-section header.
  static const double sectionHeaderBottomPadding = 8.0;

  /// Vertical spacing between record items.
  static const double itemVerticalSpacing = 0.0;

  /// Checkbox / leading-icon size. 20px sits in better proportion to 15px body.
  static const double checkboxSize = 20.0;

  /// Gap between checkbox and text.
  static const double checkboxToTextGap = 10.0;

  /// Minimum interactive touch target — HIG (44px) and Material (48px) both
  /// recommend at least 44px; we use 44 to stay closer to visual proportions.
  static const double minTouchTarget = 44.0;

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
}
