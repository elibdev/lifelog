import 'package:flutter/material.dart';

import 'package:lifelog_reference/constants/grid_constants.dart';

/// Custom decoration that paints vertical dotted lines behind a day section,
/// giving the journal a ruled-notebook aesthetic.
///
/// Flutter's Decoration/BoxPainter pattern: the framework calls createBoxPainter()
/// once and reuses the painter across frames, so painting is efficient.
/// See: https://api.flutter.dev/flutter/painting/Decoration-class.html
class DottedGridDecoration extends Decoration {
  final double horizontalOffset;
  final Color color;

  const DottedGridDecoration({
    required this.horizontalOffset,
    required this.color,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DottedGridPainter(
      horizontalOffset: horizontalOffset,
      color: color,
    );
  }
}

class _DottedGridPainter extends BoxPainter {
  final double horizontalOffset;
  final Color color;

  _DottedGridPainter({
    required this.horizontalOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double dotRadius = 0.75;
    final double spacing = GridConstants.spacing;

    // Draw dots in a grid pattern
    for (double y = offset.dy; y < offset.dy + size.height; y += spacing) {
      for (double x = offset.dx + horizontalOffset;
          x < offset.dx + size.width;
          x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }
}
