import 'package:flutter/material.dart';
import '../constants/grid_constants.dart';
import 'dotted_grid_decoration.dart';

/// Wrapper widget that renders a dotted grid background behind its child.
///
/// FLUTTER PATTERN: This is a "composition widget" - it wraps other widgets
/// to add functionality (in this case, a visual grid background). This is
/// preferred over inheritance in Flutter.
///
/// The grid:
/// - Scrolls with the content (part of the decoration, not a separate layer)
/// - Is horizontally centered with symmetric padding
/// - Adapts to theme (light/dark mode)
/// - All content should align to this grid's columns
///
/// WIDGET TREE:
/// DottedGridBackground
/// └── LayoutBuilder (gets available width)
///     └── DecoratedBox (applies grid decoration)
///         └── child (content rendered on top)
///
/// DECORATION VS STACK:
/// Previously used Stack + CustomPaint, but that created a static background.
/// DecoratedBox with custom Decoration integrates with Flutter's paint pipeline,
/// so the grid automatically scrolls with scrollable content inside.
/// See: https://api.flutter.dev/flutter/widgets/DecoratedBox-class.html
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

        // DECORATEDBOX: Paints a Decoration before drawing child
        // The decoration (grid dots) is painted as part of this widget's
        // paint phase, so if the child contains scrollable content, the
        // decoration scrolls with it naturally.
        return DecoratedBox(
          decoration: DottedGridDecoration(
            horizontalOffset: horizontalOffset,
            color: dotColor,
          ),
          child: child,
        );
      },
    );
  }
}
