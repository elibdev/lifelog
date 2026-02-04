import 'dart:ui' as ui;

/// Single source of truth for all grid-based layout dimensions.
///
/// This class ensures visual alignment by making all UI elements reference
/// a consistent 24px grid system. The grid is horizontally centered within
/// the available width, and all content (checkboxes, text, headers) aligns
/// to specific grid columns.
///
/// Design Philosophy:
/// - Grid spacing: 24px (common in bullet journals, works well with text line heights)
/// - All spacing, padding, and positioning should be derived from this grid
/// - Horizontal symmetry: grid is centered, content aligns to columns
/// - Vertical rhythm: text line heights and section spacing use grid multiples
class GridConstants {
  // ============================================================================
  // CORE GRID DIMENSIONS
  // ============================================================================

  /// Base grid spacing - all layout should be based on this
  static const double spacing = 24.0;

  /// Dot radius for the visual grid
  static const double dotRadius = 1.5;

  /// Dot color for light theme
  static const ui.Color dotColorLight = ui.Color(0xFFD0D0D0);

  /// Dot color for dark theme
  static const ui.Color dotColorDark = ui.Color(0xFF404040);

  // ============================================================================
  // HORIZONTAL LAYOUT CALCULATIONS
  // ============================================================================

  /// Calculate the number of grid columns that fit in the given width
  static int calculateColumnCount(double containerWidth) {
    return (containerWidth / spacing).floor();
  }

  /// Calculate the total width occupied by the grid
  static double calculateGridWidth(double containerWidth) {
    final columns = calculateColumnCount(containerWidth);
    return columns * spacing;
  }

  /// Calculate horizontal offset to center the grid within the container
  ///
  /// Example:
  /// - Container: 700px
  /// - Columns: 29 (floor(700/24))
  /// - Grid width: 696px (29*24)
  /// - Offset: 2px ((700-696)/2) - centers the grid
  static double calculateGridOffset(double containerWidth) {
    final gridWidth = calculateGridWidth(containerWidth);
    return (containerWidth - gridWidth) / 2;
  }

  /// Calculate left padding for content to align to grid column 2
  ///
  /// Content layout:
  /// - Column 1: Empty (provides left margin)
  /// - Column 2: Checkbox/bullet point
  /// - Column 3+: Text content
  static double calculateContentLeftPadding(double containerWidth) {
    final gridOffset = calculateGridOffset(containerWidth);
    // Content starts at column 2 (skip first column for left margin)
    return gridOffset + spacing;
  }

  // ============================================================================
  // CONTENT ELEMENT DIMENSIONS
  // ============================================================================

  /// Checkbox/bullet point size (20x20px - slightly smaller than grid spacing)
  static const double checkboxSize = 20.0;

  /// Gap between checkbox and text to align text to column 3
  ///
  /// Math:
  /// - Checkbox starts at column 2 (gridOffset + spacing)
  /// - Checkbox is 20px wide
  /// - Text should start at column 3 (gridOffset + spacing*2)
  /// - Gap needed: spacing - checkboxSize = 24 - 20 = 4px
  static const double checkboxToTextGap = spacing - checkboxSize;

  /// Text line height - should match grid spacing for vertical alignment
  /// This is a multiplier for the font size (e.g., 1.5 for 16px font = 24px line height)
  static const double textLineHeightMultiplier = 1.5;

  // ============================================================================
  // VERTICAL SPACING
  // ============================================================================

  /// Small vertical spacing between text lines (keeps items compact)
  static const double itemVerticalSpacing = 2.0;

  /// Top padding for day sections (aligns to grid row)
  static const double sectionTopPadding = spacing; // 24px

  /// Bottom padding for day section headers
  /// GRID ALIGNMENT: Changed from 8px to 12px (spacing/2) to maintain grid alignment
  /// All vertical spacing should be multiples of spacing or half-spacing
  static const double sectionHeaderBottomPadding = spacing / 2; // 12px

  /// Right padding (matches left for symmetry when centered)
  static double calculateContentRightPadding(double containerWidth) {
    // Should match left padding for visual balance
    return calculateContentLeftPadding(containerWidth);
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Snap a value to the nearest grid line
  static double snapToGrid(double value) {
    return (value / spacing).round() * spacing;
  }

  /// Calculate the grid column number for a given x-coordinate
  static int getColumnAt(double x, double containerWidth) {
    final offset = calculateGridOffset(containerWidth);
    return ((x - offset) / spacing).floor();
  }
}
