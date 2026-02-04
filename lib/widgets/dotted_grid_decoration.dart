import 'package:flutter/rendering.dart';
import '../constants/grid_constants.dart';

/// Custom Decoration that paints a dotted grid pattern.
///
/// FLUTTER PATTERN: Decoration + BoxPainter
/// Decorations (like BoxDecoration, ShapeDecoration) are immutable descriptions
/// of how to paint. They create BoxPainter instances that do the actual painting.
///
/// WHY NOT STACK + CUSTOMPAINT?
/// Using Stack with CustomPaint creates a static background layer that doesn't
/// scroll. By using a Decoration on the Container itself, the grid becomes part
/// of the container's paint process and automatically scrolls with content.
///
/// This is the same pattern used by BoxDecoration with gradients or images.
/// See: https://api.flutter.dev/flutter/painting/Decoration-class.html
class DottedGridDecoration extends Decoration {
  /// Horizontal offset to center the grid within the container
  final double horizontalOffset;

  /// Color of the dots
  final Color color;

  const DottedGridDecoration({
    required this.horizontalOffset,
    required this.color,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    // Create the painter that will draw this decoration
    return _DottedGridPainter(
      horizontalOffset: horizontalOffset,
      color: color,
    );
  }
}

/// BoxPainter that draws the dotted grid.
///
/// BOXPAINTER VS CUSTOMPAINTER:
/// - CustomPainter: Used with CustomPaint widget, good for standalone graphics
/// - BoxPainter: Used with Decorations, integrates with Flutter's paint pipeline
///
/// BoxPainter receives a Canvas and offset, and paints the decoration within
/// the given rectangle. This is called automatically during the widget's paint phase.
class _DottedGridPainter extends BoxPainter {
  final double horizontalOffset;
  final Color color;

  /// Pre-created Paint object to avoid allocations during paint()
  late final Paint _paint;

  _DottedGridPainter({
    required this.horizontalOffset,
    required this.color,
  }) {
    _paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    // configuration.size contains the size of the widget being decorated
    final size = configuration.size;
    if (size == null) return;

    final double spacing = GridConstants.spacing;
    final double dotRadius = GridConstants.dotRadius;

    // Calculate grid coverage area
    // Add offset.dy to account for scrolling position
    final int columns = ((size.width - horizontalOffset) / spacing).ceil() + 1;
    final int rows = (size.height / spacing).ceil() + 1;

    // Draw dots at each grid intersection
    // offset parameter accounts for the widget's position in the parent
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final double x = offset.dx + horizontalOffset + (col * spacing);
        final double y = offset.dy + (row * spacing);

        canvas.drawCircle(
          Offset(x, y),
          dotRadius,
          _paint,
        );
      }
    }
  }
}
