# Changelog

## Reference Implementation (`reference/`)

All reference code lives in `reference/` as a self-contained example.
The main `lib/` is untouched — write your own implementation by hand using
`reference/` to look at when needed.

### Naming Conventions
- "Block" → "Record" (single `Record` class with `RecordType` enum)
- Metadata keys namespaced by type: `todo.checked`, `heading.level`,
  `bulletList.indentLevel`, `habit.name`, `habit.frequency`, etc.

### Reference File Map

```
reference/
├── lib/
│   ├── models/
│   │   └── record.dart              # Record model + RecordType enum
│   ├── database/
│   │   ├── record_repository.dart   # CRUD + search
│   │   └── migration_v3.dart        # Schema migration guide (apply to your database_provider.dart)
│   ├── widgets/
│   │   ├── journal_screen.dart      # Main screen with infinite scroll + search FAB
│   │   ├── day_section.dart         # One section per day (replaces two RecordSections)
│   │   ├── record_section.dart      # Flat mixed-type record list + placeholder
│   │   ├── search_screen.dart       # Debounced search + date-range picker
│   │   └── records/
│   │       ├── adaptive_record_widget.dart    # Routes Record → sub-widget by type
│   │       ├── record_text_field.dart         # Shared text editing/focus/keyboard
│   │       ├── text_record_widget.dart        # Bullet + text
│   │       ├── heading_record_widget.dart     # H1/H2/H3
│   │       ├── todo_record_widget.dart        # Checkbox + strikethrough
│   │       ├── bullet_list_record_widget.dart # Indented bullets
│   │       └── habit_record_widget.dart       # Streak + tap-to-complete
│   └── services/
│       └── keyboard_service.dart    # Arrow nav, Ctrl+Enter, Delete
└── widgetbook/
    └── main.dart                    # Widgetbook with knobs for all record types
```

### What the Reference Implements

**Adaptive Record Widget**
- Single `Record` class with `RecordType` enum (text, heading, todo, bulletList, habit)
- Namespaced metadata: `todo.checked`, `heading.level`, `bulletList.indentLevel`, `habit.name`, `habit.frequency`, `habit.completions`, `habit.archived`
- `AdaptiveRecordWidget` delegates to sub-widgets via exhaustive switch
- `RecordTextField` extracts shared text editing, focus lifecycle, and keyboard handling
- Multi-line: `ConstrainedBox(minHeight)` instead of fixed `SizedBox(height)` — grows with content

**Database**
- Schema v3: adds `content` column, renames `note` → `text`, namespaces metadata keys
- `migration_v3.dart`: step-by-step guide for modifying your `database_provider.dart`
- `RecordRepository`: saveRecord, deleteRecord, getRecordsForDate, search(query, {startDate, endDate})

**Journal View**
- One `RecordSection` per day (replaces old two-section todo/note split)
- Simplified cross-day navigation (one GlobalKey per date)
- Search FAB → SearchScreen

**Search View**
- Debounced text input + date-range picker
- Results grouped by date, rendered with `AdaptiveRecordWidget` (read-only)

**Habit Records**
- Streak calculation, tap-to-complete, total completion count
- Completions stored as append-only list in namespaced metadata

**Widgetbook**
- `reference/widgetbook/main.dart` (requires `widgetbook: ^3.10.0` in dev_dependencies)
- Use-cases for all 5 record types with interactive knobs

## Planned (Future)

### Record Editing
- [ ] Multi-line: snap expanded height to grid multiples (24px increments) for dotted-grid alignment
- [ ] Support inline record type switching (typing `/` at start of empty record to pick type)
- [ ] Record reordering via drag & drop
- [ ] Undo/redo for record edits

### Navigation
- [ ] Search result → jump to record's position in journal view
- [ ] Scroll-to-today button when scrolled far from today

### Habits
- [ ] Habits summary view showing all habits with cumulative completion counts
- [ ] Support habit reset/archival without deleting history
- [ ] Weekly/custom frequency habits (not just daily)
