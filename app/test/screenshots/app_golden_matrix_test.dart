// Comprehensive golden test matrix: every screen × every device size × key
// configurations (light/dark, empty/populated, card/note view).
//
// These PNGs live in test/goldens/ and serve as a visual reference for what the
// app looks like across all states and form factors. Browse them to review UI
// without running the app.
//
// Regenerate after UI changes:  flutter test --update-goldens

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog/models/app_database.dart';
import 'package:lifelog/models/field.dart';
import 'package:lifelog/models/record.dart';
import 'package:lifelog/widgets/card_view.dart';
import 'package:lifelog/widgets/display_helpers.dart';
import 'package:lifelog/widgets/note_view.dart';
import 'package:lifelog/widgets/table_view.dart';

// ---------------------------------------------------------------------------
// Device profiles
// ---------------------------------------------------------------------------

/// Simulated device sizes for golden captures.
enum Device {
  phone(400, 800, 'phone'),
  tablet(768, 1024, 'tablet'),
  desktop(1200, 800, 'desktop');

  final double width;
  final double height;
  final String label;

  const Device(this.width, this.height, this.label);
}

void _setDevice(WidgetTester tester, Device device) {
  tester.view.physicalSize = Size(device.width, device.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ---------------------------------------------------------------------------
// Theme helpers
// ---------------------------------------------------------------------------

ThemeData _theme({bool dark = false}) => ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
    );

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
      theme: _theme(dark: dark),
      debugShowCheckedModeBanner: false,
      home: home,
    );

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _databases = [
  AppDatabase(
    id: 'db-1',
    name: 'Daily Log',
    config: const {'current_view': 'note'},
    orderPosition: 0,
    createdAt: 0,
    updatedAt: 0,
  ),
  AppDatabase(
    id: 'db-2',
    name: 'Habits',
    orderPosition: 1,
    createdAt: 0,
    updatedAt: 0,
  ),
  AppDatabase(
    id: 'db-3',
    name: 'Reading List',
    orderPosition: 2,
    createdAt: 0,
    updatedAt: 0,
  ),
  AppDatabase(
    id: 'db-4',
    name: 'People',
    orderPosition: 3,
    createdAt: 0,
    updatedAt: 0,
  ),
  AppDatabase(
    id: 'db-5',
    name: 'Projects',
    orderPosition: 4,
    createdAt: 0,
    updatedAt: 0,
  ),
];

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
        'options': ['Great', 'Good', 'Okay', 'Low']
      },
      orderPosition: 0,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-energy',
      databaseId: 'db-1',
      name: 'Energy',
      fieldType: FieldType.number,
      orderPosition: 1,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-with',
      databaseId: 'db-1',
      name: 'With',
      fieldType: FieldType.text,
      orderPosition: 2,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-highlight',
      databaseId: 'db-1',
      name: 'Highlight',
      fieldType: FieldType.checkbox,
      orderPosition: 3,
      createdAt: 0,
      updatedAt: 0),
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

// ---------------------------------------------------------------------------
// Reusable screen builders (bypass database layer, compose pure widgets)
// ---------------------------------------------------------------------------

/// Fake database list panel that doesn't hit SQLite.
Widget _databaseListPanel({
  List<AppDatabase> databases = const [],
  String? selectedId,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (context) => Text(
            'Databases',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: databases.isEmpty
            ? const Center(child: Text('No databases yet'))
            : ListView(
                children: [
                  for (final db in databases)
                    ListTile(
                      leading: const Icon(Icons.table_chart_outlined),
                      title: Text(db.name),
                      selected: db.id == selectedId,
                    ),
                ],
              ),
      ),
      const Divider(height: 1),
      const ListTile(
        leading: Icon(Icons.add),
        title: Text('New Database'),
      ),
    ],
  );
}

/// Database view screen shell with AppBar, view switcher, and FAB.
Widget _databaseViewShell({
  required Widget body,
  String title = 'Daily Log',
  String currentView = 'card',
}) {
  return Scaffold(
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
  );
}

/// Wide layout: side panel + detail area.
Widget _wideLayout({
  List<AppDatabase> databases = const [],
  String? selectedId,
  Widget? detailBody,
  String detailTitle = 'Daily Log',
  String currentView = 'card',
}) {
  return Row(
    children: [
      SizedBox(
        width: 300,
        child: Scaffold(
          body: SafeArea(
            child: _databaseListPanel(
              databases: databases,
              selectedId: selectedId,
            ),
          ),
        ),
      ),
      const VerticalDivider(width: 1, thickness: 1),
      Expanded(
        child: detailBody == null
            ? const Scaffold(
                body: Center(child: Text('Select a database')),
              )
            : _databaseViewShell(
                body: detailBody,
                title: detailTitle,
                currentView: currentView,
              ),
      ),
    ],
  );
}

/// Narrow layout: database list as home page.
Widget _narrowListLayout({
  List<AppDatabase> databases = const [],
  String? selectedId,
}) {
  return Scaffold(
    appBar: AppBar(title: const Text('Lifelog')),
    body: SafeArea(
      child: _databaseListPanel(
        databases: databases,
        selectedId: selectedId,
      ),
    ),
  );
}

/// Schema editor layout.
Widget _schemaEditorLayout({List<Field> fields = const []}) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Fields: Daily Log'),
      leading: const BackButton(),
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () {}),
      ],
    ),
    body: fields.isEmpty
        ? const Center(child: Text('No fields yet — tap + to add one'))
        : ListView(
            children: [
              for (final field in fields)
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
  );
}

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

/// Record detail layout — inline chips at top, borderless notes below.
Widget _recordDetailLayout(Record record, List<Field> fields) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Record'),
      leading: const BackButton(),
      actions: [
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
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
                    for (final field in fields)
                      _buildFieldChip(field, record, colorScheme),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: TextEditingController(text: record.content),
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
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Narrow layout — Database list
  // =========================================================================
  group('Narrow · Database List', () {
    testWidgets('with databases (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(
        _narrowListLayout(databases: _databases),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_list_phone.png'),
      );
    });

    testWidgets('with databases (tablet)', (tester) async {
      _setDevice(tester, Device.tablet);
      await tester.pumpWidget(_app(
        _narrowListLayout(databases: _databases),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_list_tablet.png'),
      );
    });

    testWidgets('empty (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(_narrowListLayout()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_list_empty_phone.png'),
      );
    });

    testWidgets('dark (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(
        _narrowListLayout(databases: _databases),
        dark: true,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_list_dark_phone.png'),
      );
    });
  });

  // =========================================================================
  // 2. Wide layout — Master-detail
  // =========================================================================
  group('Wide · Master-Detail', () {
    testWidgets('no selection (desktop)', (tester) async {
      _setDevice(tester, Device.desktop);
      await tester.pumpWidget(_app(
        _wideLayout(databases: _databases),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_no_selection_desktop.png'),
      );
    });

    testWidgets('card view selected (desktop)', (tester) async {
      _setDevice(tester, Device.desktop);
      await tester.pumpWidget(_app(
        _wideLayout(
          databases: _databases,
          selectedId: 'db-1',
          detailBody: CardView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          detailTitle: 'Daily Log',
          currentView: 'card',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_card_desktop.png'),
      );
    });

    testWidgets('note view selected (desktop)', (tester) async {
      _setDevice(tester, Device.desktop);
      await tester.pumpWidget(_app(
        _wideLayout(
          databases: _databases,
          selectedId: 'db-1',
          detailBody: NoteView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          detailTitle: 'Daily Log',
          currentView: 'note',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_note_desktop.png'),
      );
    });

    testWidgets('table view selected (desktop)', (tester) async {
      _setDevice(tester, Device.desktop);
      await tester.pumpWidget(_app(
        _wideLayout(
          databases: _databases,
          selectedId: 'db-1',
          detailBody: TableView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          detailTitle: 'Daily Log',
          currentView: 'table',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_table_desktop.png'),
      );
    });

    testWidgets('card view dark (desktop)', (tester) async {
      _setDevice(tester, Device.desktop);
      await tester.pumpWidget(_app(
        _wideLayout(
          databases: _databases,
          selectedId: 'db-1',
          detailBody: CardView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          detailTitle: 'Daily Log',
          currentView: 'card',
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_card_dark_desktop.png'),
      );
    });

    testWidgets('empty database selected (desktop)', (tester) async {
      _setDevice(tester, Device.desktop);
      await tester.pumpWidget(_app(
        _wideLayout(
          databases: _databases,
          selectedId: 'db-1',
          detailBody: CardView(
            records: const [],
            fields: _fields,
            onRecordTap: (_) {},
          ),
          detailTitle: 'Daily Log',
          currentView: 'card',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_empty_detail_desktop.png'),
      );
    });

    testWidgets('card view (tablet — near breakpoint)', (tester) async {
      // 840px+ triggers wide layout in the real app.
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(
        _wideLayout(
          databases: _databases,
          selectedId: 'db-1',
          detailBody: CardView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          detailTitle: 'Daily Log',
          currentView: 'card',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/wide_card_tablet_breakpoint.png'),
      );
    });
  });

  // =========================================================================
  // 3. Database view (narrow, standalone)
  // =========================================================================
  group('Narrow · Database View', () {
    testWidgets('card view (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(
        _databaseViewShell(
          body: CardView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_card_phone.png'),
      );
    });

    testWidgets('note view (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(
        _databaseViewShell(
          body: NoteView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          currentView: 'note',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_note_phone.png'),
      );
    });

    testWidgets('table view (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(
        _databaseViewShell(
          body: TableView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
          currentView: 'table',
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_table_phone.png'),
      );
    });

    testWidgets('card view (tablet)', (tester) async {
      _setDevice(tester, Device.tablet);
      await tester.pumpWidget(_app(
        _databaseViewShell(
          body: CardView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_card_tablet.png'),
      );
    });

    testWidgets('empty (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(Scaffold(
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
      )));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_empty_phone.png'),
      );
    });

    testWidgets('card view dark (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(
        _databaseViewShell(
          body: CardView(
            records: _records,
            fields: _fields,
            onRecordTap: (_) {},
          ),
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/narrow_card_dark_phone.png'),
      );
    });
  });

  // =========================================================================
  // 4. Record detail
  // =========================================================================
  group('Record Detail', () {
    testWidgets('with data (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(
          _app(_recordDetailLayout(_records.first, _fields)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_detail_phone.png'),
      );
    });

    testWidgets('with data (tablet)', (tester) async {
      _setDevice(tester, Device.tablet);
      await tester.pumpWidget(
          _app(_recordDetailLayout(_records.first, _fields)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_detail_tablet.png'),
      );
    });

    testWidgets('empty record (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      final emptyRecord = Record(
        id: 'r-new',
        databaseId: 'db-1',
        content: '',
        values: const {},
        orderPosition: 0,
        createdAt: 0,
        updatedAt: 0,
      );
      await tester
          .pumpWidget(_app(_recordDetailLayout(emptyRecord, _fields)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_detail_empty_phone.png'),
      );
    });

    testWidgets('dark (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(
          _app(_recordDetailLayout(_records.first, _fields), dark: true));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_detail_dark_phone.png'),
      );
    });
  });

  // =========================================================================
  // 5. Schema editor
  // =========================================================================
  group('Schema Editor', () {
    testWidgets('with fields (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester
          .pumpWidget(_app(_schemaEditorLayout(fields: _fields)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/schema_editor_phone.png'),
      );
    });

    testWidgets('with fields (tablet)', (tester) async {
      _setDevice(tester, Device.tablet);
      await tester
          .pumpWidget(_app(_schemaEditorLayout(fields: _fields)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/schema_editor_tablet.png'),
      );
    });

    testWidgets('empty (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(_app(_schemaEditorLayout()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/schema_editor_empty_phone.png'),
      );
    });

    testWidgets('dark (phone)', (tester) async {
      _setDevice(tester, Device.phone);
      await tester.pumpWidget(
          _app(_schemaEditorLayout(fields: _fields), dark: true));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/schema_editor_dark_phone.png'),
      );
    });
  });
}
