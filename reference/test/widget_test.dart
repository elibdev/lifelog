import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifelog_reference/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const LifelogReferenceApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
