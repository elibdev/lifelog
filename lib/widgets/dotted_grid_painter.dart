import 'package:flutter/rendering.dart';
import '../constants/grid_constants.dart';

/// CustomPainter that draws a dotted grid pattern.
///
/// FLUTTER CONCEPT: CustomPainter
/// CustomPainter gives you direct access to Canvas - Flutter's low-level
/// drawing API (similar to HTML Canvas or Android Canvas). Use it when you
/// need to draw custom graphics that aren't available as built-in widgets.
///
/// LIFECYCLE: CustomPainter.paint() is called whenever:
/// - The widget is first built
/// - The size changes
/// - shouldRepaint() returns true (when properties change)
///
/// PERFORMANCE: Canvas operations are efficient, but avoid creating new
/// objects in paint() - store them as fields instead (like _paint below).
///
/// See: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
class DottedGridPainter extends CustomPainter {
  /// Horizontal offset to center the grid within the container
  final double horizontalOffset;

  /// Color of the dots (theme-aware, passed from parent)
  final Color color;

  /// Pre-created Paint object to avoid allocations in paint()
  /// DART PERFORMANCE TIP: Create Paint objects once and reuse them
  late final Paint _paint;

  DottedGridPainter({
    required this.horizontalOffset,
    required this.color,
  }) {
    // Initialize Paint object once in constructor
    _paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill; // Fill the circles (not stroke)
  }

  @override
  void paint(Canvas canvas, Size size) {
    // CANVAS DRAWING: Loop through grid positions and draw circles
    // Start from horizontalOffset to center the grid horizontally

    final double spacing = GridConstants.spacing;
    final double dotRadius = GridConstants.dotRadius;

    // Calculate how many rows and columns we need to cover the entire area
    final int columns = ((size.width - horizontalOffset) / spacing).ceil() + 1;
    final int rows = (size.height / spacing).ceil() + 1;

    // Draw dots at each grid intersection
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final double x = horizontalOffset + (col * spacing);
        final double y = row * spacing;

        // Only draw if the dot is within the canvas bounds
        if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
          canvas.drawCircle(
            Offset(x, y),
            dotRadius,
            _paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(DottedGridPainter oldDelegate) {
    // Repaint if the offset or color changed
    // PERFORMANCE: Return false if nothing changed to avoid unnecessary repaints
    return oldDelegate.horizontalOffset != horizontalOffset ||
        oldDelegate.color != color;
  }
}
