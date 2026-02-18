import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog_reference/widgets/dotted_grid_decoration.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';

void _setWindowSize(WidgetTester tester, {double width = 400, double height = 300}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('DottedGridDecoration', () {
    testWidgets('light theme', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          // DottedGridDecoration is a BoxDecoration painted directly on a Container.
          // No MaterialApp theme is needed for the decoration itself — it takes
          // explicit color params — but we wrap in MaterialApp for test consistency.
          home: Scaffold(
            body: Container(
              decoration: const DottedGridDecoration(
                horizontalOffset: 16,
                color: GridConstants.dotColorLight,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/dotted_grid_light.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Container(
              decoration: const DottedGridDecoration(
                horizontalOffset: 16,
                color: GridConstants.dotColorDark,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/dotted_grid_dark.png'),
      );
    });
  });
}
