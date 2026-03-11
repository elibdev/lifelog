import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog/models/field.dart';
import 'package:lifelog/models/record.dart';
import 'package:lifelog/widgets/card_view.dart';
import 'package:lifelog/widgets/display_helpers.dart';
import 'package:lifelog/widgets/note_view.dart';
import 'package:lifelog/widgets/table_view.dart';

// These tests render screen-like compositions (AppBar + views) to capture
// golden PNGs of the full UI layout. They bypass the database layer by
// providing data directly to the pure view widgets.

Widget _wrapScreen(Widget body, {String title = 'Daily Log', String currentView = 'card', bool dark = false}) {
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
            value: currentView,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'note', child: Text('Note')),
              DropdownMenuItem(value: 'table', child: Text('Table')),
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

// Fixed timestamps for golden-stable date display.
final _march5 = DateTime(2026, 3, 5).millisecondsSinceEpoch;
final _march4 = DateTime(2026, 3, 4).millisecondsSinceEpoch;
final _march3 = DateTime(2026, 3, 3).millisecondsSinceEpoch;

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
    createdAt: _march5,
    updatedAt: _march5,
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
    createdAt: _march4,
    updatedAt: _march4,
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
    createdAt: _march3,
    updatedAt: _march3,
  ),
];

/// Build a field chip matching the RecordDetailScreen's inline chip layout.
Widget _buildFieldChip(Field field, Record record, ColorScheme colorScheme) {
  final value = record.getValue(field.id);
  switch (field.fieldType) {
    case FieldType.checkbox:
      final checked = value == true;
      return ActionChip(
        avatar: Icon(
          checked ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: checked ? colorScheme.primary : null,
        ),
        label: Text(field.name),
        onPressed: () {},
      );
    case FieldType.select:
      final strValue = value as String?;
      final hasValue = strValue != null && strValue.isNotEmpty;
      final colors = hasValue
          ? selectOptionColors(
              value: strValue,
              options: field.selectOptions,
              colorScheme: colorScheme,
            )
          : null;
      return Chip(
        label: Text(
          hasValue ? strValue : field.name,
          style: colors != null ? TextStyle(color: colors.fg) : null,
        ),
        backgroundColor: colors?.bg,
        side: colors != null ? BorderSide.none : null,
      );
    case FieldType.text:
      final strValue = (value as String?) ?? '';
      return ActionChip(
        label:
            Text(strValue.isEmpty ? field.name : '${field.name}: $strValue'),
        onPressed: () {},
      );
    case FieldType.number:
      final strValue = (value ?? '').toString();
      return ActionChip(
        label:
            Text(strValue.isEmpty ? field.name : '${field.name}: $strValue'),
        onPressed: () {},
      );
    case FieldType.date:
      final strValue = (value as String?) ?? '';
      return ActionChip(
        avatar: const Icon(Icons.calendar_today, size: 16),
        label: Text(strValue.isEmpty ? field.name : strValue),
        onPressed: () {},
      );
    case FieldType.relation:
      return ActionChip(
        avatar: const Icon(Icons.link, size: 16),
        label: Text(field.name),
        onPressed: () {},
      );
  }
}

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
        currentView: 'note',
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
        currentView: 'table',
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
  // inline chips at top, borderless notes filling remaining space.
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
          body: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final field in _fields)
                            _buildFieldChip(field, record, colorScheme),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextField(
                        controller:
                            TextEditingController(text: record.content),
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Write here...',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
