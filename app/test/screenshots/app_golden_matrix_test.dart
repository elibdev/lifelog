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
    name: 'Books',
    orderPosition: 0,
    createdAt: 0,
    updatedAt: 0,
  ),
  AppDatabase(
    id: 'db-2',
    name: 'Projects',
    config: const {'current_view': 'note'},
    orderPosition: 1,
    createdAt: 0,
    updatedAt: 0,
  ),
  AppDatabase(
    id: 'db-3',
    name: 'Recipes',
    orderPosition: 2,
    createdAt: 0,
    updatedAt: 0,
  ),
];

final _fields = [
  Field(
      id: 'f-title',
      databaseId: 'db-1',
      name: 'Title',
      fieldType: FieldType.text,
      orderPosition: 0,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-author',
      databaseId: 'db-1',
      name: 'Author',
      fieldType: FieldType.text,
      orderPosition: 1,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-rating',
      databaseId: 'db-1',
      name: 'Rating',
      fieldType: FieldType.number,
      orderPosition: 2,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-status',
      databaseId: 'db-1',
      name: 'Status',
      fieldType: FieldType.select,
      config: const {
        'options': ['To Read', 'Reading', 'Finished']
      },
      orderPosition: 3,
      createdAt: 0,
      updatedAt: 0),
  Field(
      id: 'f-favorite',
      databaseId: 'db-1',
      name: 'Favorite',
      fieldType: FieldType.checkbox,
      orderPosition: 4,
      createdAt: 0,
      updatedAt: 0),
];

final _records = [
  Record(
    id: 'r-1',
    databaseId: 'db-1',
    content: 'A classic novel about the American dream.\n\n'
        'Chapter 1 notes:\n'
        '- Nick moves to West Egg\n'
        '- Meets mysterious neighbor Gatsby',
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
  String title = 'Books',
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
  String detailTitle = 'Books',
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
      title: const Text('Fields: Books'),
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

/// Record detail layout.
Widget _recordDetailLayout(Record record, List<Field> fields) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Record'),
      leading: const BackButton(),
      actions: [
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
      ],
    ),
    body: Column(
      children: [
        Flexible(
          flex: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              shrinkWrap: true,
              children: [
                for (final field in fields.where(
                    (f) => f.fieldType != FieldType.checkbox)) ...[
                  TextField(
                    controller: TextEditingController(
                      text: record.values[field.id]?.toString() ?? '',
                    ),
                    keyboardType: field.fieldType == FieldType.number
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: field.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final field
                    in fields.where((f) => f.fieldType == FieldType.checkbox))
                  CheckboxListTile(
                    title: Text(field.name),
                    value: record.values[field.id] == true,
                    onChanged: (_) {},
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) => Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: record.content),
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
          detailTitle: 'Books',
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
          detailTitle: 'Books',
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
          detailTitle: 'Books',
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
          detailTitle: 'Books',
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
          detailTitle: 'Books',
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
          detailTitle: 'Books',
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
