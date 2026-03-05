import 'package:flutter_test/flutter_test.dart';

import 'package:lifelog/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const LifelogApp());
    expect(find.text('Lifelog'), findsOneWidget);
  });
}
