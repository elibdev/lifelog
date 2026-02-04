import 'package:flutter/material.dart';
import '../constants/grid_constants.dart';
import 'dotted_grid_painter.dart';

/// Wrapper widget that renders a dotted grid background behind its child.
///
/// FLUTTER PATTERN: This is a "composition widget" - it wraps other widgets
/// to add functionality (in this case, a visual grid background). This is
/// preferred over inheritance in Flutter.
///
/// The grid:
/// - Scrolls with the content (not stationary)
/// - Is horizontally centered with symmetric padding
/// - Adapts to theme (light/dark mode)
/// - All content should align to this grid's columns
///
/// WIDGET TREE:
/// DottedGridBackground
/// └── LayoutBuilder (gets available width)
///     └── Stack (layers child on top of grid)
///         ├── CustomPaint (grid dots - background layer)
///         └── child (content - foreground layer)
class DottedGridBackground extends StatelessWidget {
  /// The content to render on top of the grid
  final Widget child;

  const DottedGridBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Get theme brightness to determine dot color
    // FLUTTER THEMING: Theme.of(context) accesses the nearest Theme widget
    // up the tree. Material apps provide this automatically.
    final brightness = Theme.of(context).brightness;
    final dotColor = brightness == Brightness.light
        ? GridConstants.dotColorLight
        : GridConstants.dotColorDark;

    // LAYOUTBUILDER: Gives us the exact constraints from the parent
    // We need this to calculate horizontal centering for the grid
    // See: https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate how much to offset the grid horizontally to center it
        final horizontalOffset = GridConstants.calculateGridOffset(
          constraints.maxWidth,
        );

        // STACK: Layers widgets on top of each other (z-axis)
        // Unlike Column/Row (which lay out on x/y axes), Stack uses absolute
        // positioning. First child is at the bottom, last child on top.
        // See: https://api.flutter.dev/flutter/widgets/Stack-class.html
        return Stack(
          children: [
            // Background layer: Grid dots
            // CustomPaint draws custom graphics using our DottedGridPainter
            CustomPaint(
              size: Size.infinite, // Fill the entire available space
              painter: DottedGridPainter(
                horizontalOffset: horizontalOffset,
                color: dotColor,
              ),
            ),
            // Foreground layer: Content
            child,
          ],
        );
      },
    );
  }
}
