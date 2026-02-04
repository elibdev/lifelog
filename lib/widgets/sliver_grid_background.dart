import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../constants/grid_constants.dart';

/// A sliver that paints a continuous dotted grid behind all scrollable content.
///
/// FLUTTER SLIVER CONCEPT:
/// Slivers are scrollable areas that efficiently handle large lists by only
/// rendering visible items. This custom sliver paints a grid pattern that
/// scrolls naturally with the content.
///
/// APPROACH:
/// We create a sliver that takes up no space (extent = 0) but paints a grid
/// across the entire viewport. By inserting this as the first sliver in the
/// CustomScrollView, it appears behind all content and scrolls naturally.
///
/// This solves the "uneven dots" problem where decorating individual
/// DaySections created discontinuities at section boundaries.
class SliverGridBackground extends SingleChildRenderObjectWidget {
  final Color color;
  final double horizontalOffset;

  const SliverGridBackground({
    super.key,
    required this.color,
    required this.horizontalOffset,
    super.child,
  });

  @override
  RenderSliverGridBackground createRenderObject(BuildContext context) {
    return RenderSliverGridBackground(
      color: color,
      horizontalOffset: horizontalOffset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverGridBackground renderObject,
  ) {
    renderObject
      ..color = color
      ..horizontalOffset = horizontalOffset;
  }
}

/// Custom RenderSliver that paints the dotted grid.
///
/// FLUTTER RENDERING:
/// RenderObject is Flutter's low-level rendering abstraction. This custom
/// RenderSliver integrates with the scrolling machinery to paint a grid that
/// moves with the content.
///
/// KEY METHODS:
/// - performLayout(): Sets the sliver's geometry (we use 0 extent - no space)
/// - paint(): Draws the grid dots on the canvas
///
/// See: https://api.flutter.dev/flutter/rendering/RenderSliver-class.html
class RenderSliverGridBackground extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox> {
  Color _color;
  double _horizontalOffset;

  RenderSliverGridBackground({
    required Color color,
    required double horizontalOffset,
  })  : _color = color,
        _horizontalOffset = horizontalOffset;

  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  double get horizontalOffset => _horizontalOffset;
  set horizontalOffset(double value) {
    if (_horizontalOffset == value) return;
    _horizontalOffset = value;
    markNeedsPaint();
  }

  late final Paint _paint = Paint()
    ..style = PaintingStyle.fill;

  @override
  void performLayout() {
    // This sliver takes up no space in the scroll view
    // geometry determines the sliver's size and scroll behavior
    geometry = SliverGeometry(
      scrollExtent: 0, // Doesn't contribute to scrollable height
      paintExtent: 0, // Doesn't take up visible space
      maxPaintExtent: 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Get the viewport's constraints to know what area to paint
    final SliverConstraints constraints = this.constraints;
    final double viewportHeight = constraints.viewportMainAxisExtent;
    final double viewportWidth = constraints.crossAxisExtent;

    // scrollOffset tells us how far the user has scrolled
    // We use this to calculate which grid dots should be visible
    final double scrollOffset = constraints.scrollOffset;

    final double spacing = GridConstants.spacing;
    final double dotRadius = GridConstants.dotRadius;

    // Calculate which grid dots should appear in the current viewport
    // Global grid has dots at y = 0, 24, 48, 72...
    // Viewport shows content from scrollOffset to scrollOffset + viewportHeight

    // Find the first grid row that should be visible
    final int firstVisibleRow = (scrollOffset / spacing).floor();
    final int lastVisibleRow =
        ((scrollOffset + viewportHeight) / spacing).ceil() + 1;

    // Calculate columns based on viewport width
    final int columns =
        ((viewportWidth - _horizontalOffset) / spacing).ceil() + 1;

    _paint.color = _color;

    // Paint dots for all visible grid positions
    for (int row = firstVisibleRow; row <= lastVisibleRow; row++) {
      final double globalY = row * spacing;
      // Convert global y position to viewport coordinates
      final double localY = globalY - scrollOffset;

      for (int col = 0; col < columns; col++) {
        final double x = _horizontalOffset + (col * spacing);

        context.canvas.drawCircle(
          Offset(offset.dx + x, offset.dy + localY),
          dotRadius,
          _paint,
        );
      }
    }
  }
}
