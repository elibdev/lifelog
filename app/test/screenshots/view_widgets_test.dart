import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog/models/field.dart';
import 'package:lifelog/models/record.dart';
import 'package:lifelog/widgets/card_view.dart';
import 'package:lifelog/widgets/note_view.dart';

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

// Sample fields for a "Books" database.
final _fields = [
  Field(
    id: 'f-title',
    databaseId: 'db-1',
    name: 'Title',
    fieldType: FieldType.text,
    orderPosition: 0,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-author',
    databaseId: 'db-1',
    name: 'Author',
    fieldType: FieldType.text,
    orderPosition: 1,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-rating',
    databaseId: 'db-1',
    name: 'Rating',
    fieldType: FieldType.number,
    orderPosition: 2,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-status',
    databaseId: 'db-1',
    name: 'Status',
    fieldType: FieldType.select,
    config: const {
      'options': ['To Read', 'Reading', 'Finished'],
    },
    orderPosition: 3,
    createdAt: 0,
    updatedAt: 0,
  ),
  Field(
    id: 'f-favorite',
    databaseId: 'db-1',
    name: 'Favorite',
    fieldType: FieldType.checkbox,
    orderPosition: 4,
    createdAt: 0,
    updatedAt: 0,
  ),
];

final _records = [
  Record(
    id: 'r-1',
    databaseId: 'db-1',
    content: 'A classic novel about the American dream.\n\n'
        'Chapter 1 notes:\n'
        '- Nick moves to West Egg\n'
        '- Meets mysterious neighbor Gatsby\n'
        '- Attends lavish party across the bay',
    values: const {
      'f-title': 'The Great Gatsby',
      'f-author': 'F. Scott Fitzgerald',
      'f-rating': '5',
      'f-status': 'Finished',
      'f-favorite': true,
    },
    orderPosition: 0,
    createdAt: 0,
    updatedAt: 0,
  ),
  Record(
    id: 'r-2',
    databaseId: 'db-1',
    content: 'Interesting take on dystopian surveillance society.\n'
        'The parallels to modern technology are striking.',
    values: const {
      'f-title': '1984',
      'f-author': 'George Orwell',
      'f-rating': '4',
      'f-status': 'Finished',
      'f-favorite': false,
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
      'f-title': 'Dune',
      'f-author': 'Frank Herbert',
      'f-status': 'Reading',
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
}
