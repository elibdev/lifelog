import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog/models/field.dart';
import 'package:lifelog/models/record.dart';
import 'package:lifelog/widgets/card_view.dart';
import 'package:lifelog/widgets/note_view.dart';
import 'package:lifelog/widgets/table_view.dart';

// These tests render screen-like compositions (AppBar + views) to capture
// golden PNGs of the full UI layout. They bypass the database layer by
// providing data directly to the pure view widgets.

Widget _wrapScreen(Widget body, {String title = 'Daily Log', bool dark = false}) {
  return MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
    ),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          DropdownButton<String>(
            value: 'card',
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'note', child: Text('Note')),
            ],
            onChanged: (_) {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    ),
  );
}

void _setWindowSize(WidgetTester tester,
    {double width = 400, double height = 800}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

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
  group('DatabaseViewScreen layout', () {
    testWidgets('card view', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrapScreen(
        CardView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
        title: 'Daily Log',
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/database_screen_card.png'),
      );
    });

    testWidgets('note view', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrapScreen(
        NoteView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
        title: 'Daily Log',
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/database_screen_note.png'),
      );
    });

    testWidgets('table view', (tester) async {
      _setWindowSize(tester, width: 600, height: 400);
      await tester.pumpWidget(_wrapScreen(
        TableView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
        title: 'Daily Log',
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/database_screen_table.png'),
      );
    });

    testWidgets('card view dark', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrapScreen(
        CardView(
          records: _records,
          fields: _fields,
          onRecordTap: (_) {},
        ),
        title: 'Daily Log',
        dark: true,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/database_screen_card_dark.png'),
      );
    });

    testWidgets('empty database', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('New Database')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No records yet'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add Record'),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/database_screen_empty.png'),
      );
    });
  });

  group('SchemaEditor layout', () {
    testWidgets('with fields', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Fields: Daily Log'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {},
              ),
            ],
          ),
          body: ListView(
            children: [
              for (final field in _fields)
                ListTile(
                  key: ValueKey(field.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(field.name),
                  subtitle: Text(field.fieldType.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/schema_editor.png'),
      );
    });
  });

  // RecordDetail golden tests mirror the actual RecordDetailScreen layout:
  // fields in a constrained scrollable header, notes filling remaining space
  // via Expanded + TextField(expands: true).
  group('RecordDetail layout', () {
    testWidgets('with field values and multiline notes', (tester) async {
      _setWindowSize(tester);
      final record = _records.first;

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Record'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {},
              ),
            ],
          ),
          // Mirrors the Column layout from RecordDetailScreen.
          body: Column(
            children: [
              // Field editors in a constrained scrollable area.
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    shrinkWrap: true,
                    children: [
                      TextField(
                        controller: TextEditingController(
                            text: record.values['f-mood'] as String?),
                        decoration: const InputDecoration(
                          labelText: 'Mood',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(
                            text: record.values['f-energy']?.toString()),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Energy',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(
                            text: record.values['f-with'] as String?),
                        decoration: const InputDecoration(
                          labelText: 'With',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Highlight'),
                        value: record.values['f-highlight'] == true,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Notes area fills remaining space.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes',
                          style: ThemeData(useMaterial3: true)
                              .textTheme
                              .titleSmall),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller:
                              TextEditingController(text: record.content),
                          expands: true,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Write notes here...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_detail.png'),
      );
    });
  });
}
