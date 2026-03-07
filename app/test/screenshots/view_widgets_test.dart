import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog/models/field.dart';
import 'package:lifelog/models/record.dart';
import 'package:lifelog/widgets/card_view.dart';
import 'package:lifelog/widgets/note_view.dart';
import 'package:lifelog/widgets/table_view.dart';

// Wrap a widget in a Material 3 themed app matching the real app's look.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      brightness: Brightness.light,
    ),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  );
}

Widget _wrapDark(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      brightness: Brightness.dark,
    ),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  );
}

// Set a fixed logical pixel window for stable golden output.
void _setWindowSize(WidgetTester tester,
    {double width = 400, double height = 600}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// Sample fields for a "Daily Log" database — the core life journaling schema.
final _fields = [
  Field(
    id: 'f-mood',
    databaseId: 'db-1',
    name: 'Mood',
    fieldType: FieldType.select,
    config: const {
      'options': ['Great', 'Good', 'Okay', 'Low'],
    },
    orderPosition: 0,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-energy',
    databaseId: 'db-1',
    name: 'Energy',
    fieldType: FieldType.number,
    orderPosition: 1,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-with',
    databaseId: 'db-1',
    name: 'With',
    fieldType: FieldType.text,
    orderPosition: 2,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-highlight',
    databaseId: 'db-1',
    name: 'Highlight',
    fieldType: FieldType.checkbox,
    orderPosition: 3,
    createdAt: 0,
    updatedAt: 0,
  ),
];

final _records = [
  Record(
    id: 'r-1',
    databaseId: 'db-1',
    content: 'Had an amazing morning run along the river — 7K and felt '
        'strong the whole way. Met Sarah for coffee at Bluestone Lane '
        'and talked about her upcoming gallery show.\n\n'
        'Afternoon: deep work session on the API redesign. Finally '
        'cracked the caching problem I\'ve been stuck on all week. '
        'That feeling when it clicks.',
    values: const {
      'f-mood': 'Great',
      'f-energy': '8',
      'f-with': 'Sarah, Marcus',
      'f-highlight': true,
    },
    orderPosition: 0,
    createdAt: 0,
    updatedAt: 0,
  ),
  Record(
    id: 'r-2',
    databaseId: 'db-1',
    content: 'Solid workday. Shipped the onboarding flow redesign.\n'
        'Evening run — 5K in 24:30, getting faster.\n'
        'Cooked mushroom risotto from the Ottolenghi book.',
    values: const {
      'f-mood': 'Good',
      'f-energy': '6',
      'f-with': 'Team standup',
      'f-highlight': false,
    },
    orderPosition: 1,
    createdAt: 0,
    updatedAt: 0,
  ),
  Record(
    id: 'r-3',
    databaseId: 'db-1',
    content: '',
    values: const {
      'f-mood': 'Okay',
      'f-energy': '4',
    },
    orderPosition: 2,
    createdAt: 0,
    updatedAt: 0,
  ),
];

void main() {
  group('CardView', () {
    testWidgets('with records', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        CardView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/card_view.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrapDark(
        CardView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/card_view_dark.png'),
      );
    });

    testWidgets('empty state', (tester) async {
      _setWindowSize(tester, height: 200);
      await tester.pumpWidget(_wrap(
        CardView(
          records: const [],
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/card_view_empty.png'),
      );
    });
  });

  group('NoteView', () {
    testWidgets('with records', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        NoteView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/note_view.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrapDark(
        NoteView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/note_view_dark.png'),
      );
    });
  });

  group('TableView', () {
    testWidgets('with records', (tester) async {
      _setWindowSize(tester, width: 600, height: 400);
      await tester.pumpWidget(_wrap(
        TableView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/table_view.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      _setWindowSize(tester, width: 600, height: 400);
      await tester.pumpWidget(_wrapDark(
        TableView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/table_view_dark.png'),
      );
    });

    testWidgets('empty state', (tester) async {
      _setWindowSize(tester, width: 600, height: 200);
      await tester.pumpWidget(_wrap(
        TableView(
          records: const [],
          fields: _fields,
          onRecordTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/table_view_empty.png'),
      );
    });
  });
}
