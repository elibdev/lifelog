/// Layout constants for the journal grid system.
///
/// Based on an 8px grid — Swiss typographic precision.
/// Every dimension is a multiple of 8 or a deliberate half-step (4px).
class GridConstants {
  GridConstants._();

  /// Base grid unit.
  static const double unit = 8.0;

  /// Minimum record row height — ensures consistent vertical rhythm.
  static const double rowHeight = 28.0;

  /// Line-height multiplier for body text.
  static const double textLineHeightMultiplier = 1.5;

  /// Vertical padding above a day section.
  static const double sectionTopPadding = 24.0;

  /// Space below the day section header rule.
  static const double sectionHeaderBottomPadding = 12.0;

  /// Vertical spacing between record items.
  static const double itemVerticalSpacing = 1.0;

  /// Checkbox / leading-icon size.
  static const double checkboxSize = 20.0;

  /// Gap between checkbox/bullet and text.
  static const double checkboxToTextGap = 10.0;

  /// Indent step for nested bullet lists.
  static const double indentStep = 24.0;

  /// Responsive content padding — wider screens get more breathing room.
  static double calculateContentLeftPadding(double screenWidth) {
    if (screenWidth > 900) return 64.0;
    if (screenWidth >= 600) return 40.0;
    return 20.0;
  }

  static double calculateContentRightPadding(double screenWidth) {
    if (screenWidth > 900) return 64.0;
    if (screenWidth >= 600) return 40.0;
    return 20.0;
  }
}
