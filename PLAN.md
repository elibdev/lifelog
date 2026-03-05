# Database Redesign: Note Database with User-Defined Schemas

## Data Model

### Core Concept

Users create **databases** (like Airtable tables). Each database has a **schema**
(ordered list of fields with types). **Records** are rows in a database. Records
can be **linked** to each other across databases via an associative table.

Every record has a built-in `content` text field (plain text, FTS-indexed) that
serves as an optional note body. This means any record can double as a note without
needing a special "note" field type.

### SQLite Tables

```sql
-- User-created databases (e.g. "Books", "Projects", "People")
CREATE TABLE databases (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  config TEXT NOT NULL DEFAULT '{}', -- JSON: view prefs, icon, color, future settings
  order_position REAL NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Schema definition: one row per field per database
CREATE TABLE fields (
  id TEXT PRIMARY KEY,
  database_id TEXT NOT NULL REFERENCES databases(id),
  name TEXT NOT NULL,              -- display name, e.g. "Author"
  field_type TEXT NOT NULL,        -- text | number | checkbox | date | select | relation
  config TEXT NOT NULL DEFAULT '{}', -- JSON: select options, relation target db, etc.
  order_position REAL NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_fields_database ON fields(database_id);

-- Records: one row per entry in a database
-- Field values stored as JSON: { "field_id_1": "value", "field_id_2": 42, ... }
CREATE TABLE records (
  id TEXT PRIMARY KEY,
  database_id TEXT NOT NULL REFERENCES databases(id),
  content TEXT NOT NULL DEFAULT '',   -- plain text note body, always FTS-indexed
  values_json TEXT NOT NULL DEFAULT '{}', -- structured field values as JSON
  order_position REAL NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_records_database ON records(database_id);

-- FTS index on record content (same pattern as current app)
CREATE VIRTUAL TABLE records_fts USING fts5(content);
-- rowid mapping: records_fts.rowid = records.rowid

-- Associative table for record-to-record links
-- Each link is created by a "relation" field on the source side
CREATE TABLE record_links (
  source_record_id TEXT NOT NULL REFERENCES records(id),
  target_record_id TEXT NOT NULL REFERENCES records(id),
  field_id TEXT NOT NULL REFERENCES fields(id),  -- which relation field created this
  created_at INTEGER NOT NULL,
  PRIMARY KEY (source_record_id, target_record_id, field_id)
);
CREATE INDEX idx_links_target ON record_links(target_record_id);

-- Keep event_log for future sync/undo support
CREATE TABLE event_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,       -- 'database', 'field', 'record', 'link'
  entity_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  device_id TEXT
);
```

### Field Types (MVP)

| Type       | Stored in `values_json` as | Notes |
|------------|---------------------------|-------|
| text       | `"string value"`          | Short text, single line |
| number     | `42` or `3.14`            | Any numeric value |
| checkbox   | `true` / `false`          | Boolean |
| date       | `"2026-03-04"`            | ISO 8601 date string |
| select     | `"option_value"`          | Single select; options stored in field `config` |
| relation   | *(not in values_json)*    | Links stored in `record_links` table instead |

### Field `config` JSON Examples

```json
// select field
{ "options": ["To Read", "Reading", "Finished"] }

// relation field
{ "target_database_id": "uuid-of-target-db" }
```

### Database `config` JSON Examples

```json
// View preferences — current view and any saved per-view settings
{ "current_view": "card", "views": { "card": {}, "note": {} } }

// Future: icon, color, description, default sort, filters, etc.
{ "current_view": "card", "icon": "book", "color": "#4A90D9" }
```

### Extensibility / Backwards Compatibility

Every extension point in the schema is additive — nothing requires ALTER TABLE:

- **New field types**: Just a new `field_type` string value + Dart handling code.
  Unknown types render as raw text (graceful degradation). `config` JSON holds
  whatever the new type needs.
- **New view types**: `databases.config` stores `current_view` and per-view settings.
  Adding a "table" or "gallery" view later is just new UI code + a new key in config.
- **Rich text later**: `content` column stays TEXT. Switch from plain strings to
  a structured format (markdown, ProseMirror JSON, etc.) — old plain text is valid
  input for any rich-text renderer.
- **Multi-select**: New field type. Value stored as JSON array in `values_json`.
- **Attachments/files**: New field type. File paths or references in `values_json`,
  extra config in field `config`.
- **Formulas/rollups**: New field types. Formula expression stored in `config`,
  computed value optionally cached in `values_json`.
- **Record metadata**: `values_json` can hold system-generated keys alongside
  user-defined field values (prefix with `_` to namespace).

### Dart Models

```
AppDatabase        – id, name, config (Map<String,dynamic>), orderPosition, createdAt, updatedAt
Field              – id, databaseId, name, fieldType (enum), config, orderPosition, ...
Record             – id, databaseId, content, values (Map<String,dynamic>), orderPosition, ...
RecordLink         – sourceRecordId, targetRecordId, fieldId, createdAt
```

### Why This Design

- **One `records` table, not one table per user-database**: Keeps schema changes
  (add/remove/reorder fields) trivial — just update the `fields` table and
  `values_json`. No ALTER TABLE needed.
- **`values_json` as JSON blob**: SQLite's `json_extract()` can query into it when
  needed. Simple to read/write from Dart. Trade-off: no per-column indexing, but
  for an MVP with local data this is fine.
- **Built-in `content` column**: Every record is also a note. FTS comes free.
  No special "note type" needed.
- **`record_links` associative table**: Clean separation of link data. The `field_id`
  column ties each link back to the relation field that created it, so you can have
  multiple relation fields between the same two databases.
- **`order_position` as REAL**: Same pattern you already use — allows reordering
  by averaging neighbors without rewriting all rows.

### Migration Path

This is a full schema reset (new tables), not an incremental migration from the
journal schema. The `reference/` directory preserves the old code. New code starts
fresh in `lib/`.

---

## UI Plan

### Navigation Structure

```
┌─────────────────────────────────────────┐
│  Sidebar / Drawer                       │
│  ┌───────────────────────────────────┐  │
│  │ 📋 Books                         │  │
│  │ 📋 Projects                      │  │
│  │ 📋 People                        │  │
│  │ + New Database                    │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

- Drawer/sidebar lists all databases
- Tap a database → opens its view
- "+ New Database" at the bottom

### Database View Screen

Top bar has the database name and a **view switcher** (dropdown or segmented
control). MVP ships with two views: **Card** and **Note**.

```
┌─────────────────────────────────────────┐
│  Books            [Card ▾]   [+ Field]  │
│  [🔍 Search]                            │
├─────────────────────────────────────────┤
│                                         │
│  (view content rendered here)           │
│                                         │
│                          [+ New Record] │
└─────────────────────────────────────────┘
```

### Card View

Each record is a card showing field values in a compact layout. The first text
field (or the record title/content) is prominent. Other fields render as
label: value pairs below.

```
┌─────────────────────────────────────────┐
│  The Great Gatsby                       │
│  Author: F. Scott Fitzgerald            │
│  Status: Reading                        │
│  Rating: ★★★★                          │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│  1984                                   │
│  Author: George Orwell                  │
│  Status: Finished                       │
│  Rating: ★★★★★                         │
└─────────────────────────────────────────┘
```

- Cards are vertically scrollable
- Tap a card → opens **Record Detail** screen

### Note View

Each record renders as a note/document block. The `content` field is prominent
(multi-line text area). Structured fields show as a compact header above the
content.

```
┌─────────────────────────────────────────┐
│  The Great Gatsby                       │
│  Author: Fitzgerald · Status: Reading   │
│  ─────────────────────────────────────  │
│  Chapter 3 thoughts: The party scene    │
│  reveals Gatsby's loneliness despite    │
│  the crowd...                           │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│  1984                                   │
│  Author: Orwell · Status: Finished      │
│  ─────────────────────────────────────  │
│  The ending is devastating. Winston's   │
│  surrender feels inevitable in          │
│  retrospect...                          │
└─────────────────────────────────────────┘
```

- Note view emphasizes `content` — good for databases used primarily as notes
- Fields collapsed into a single-line summary

### Record Detail Screen

Full editing view for a single record. Opened by tapping a card/note.

```
┌─────────────────────────────────────────┐
│  ← Back                       [Delete]  │
├─────────────────────────────────────────┤
│  Title:   [The Great Gatsby          ]  │
│  Author:  [F. Scott Fitzgerald       ]  │
│  Status:  [Reading ▾                 ]  │
│  Rating:  [4                         ]  │
├─────────────────────────────────────────┤
│  Notes                                  │
│  ┌───────────────────────────────────┐  │
│  │ Chapter 3 thoughts: The party    │  │
│  │ scene reveals Gatsby's           │  │
│  │ loneliness despite the crowd...  │  │
│  │                                  │  │
│  └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│  Linked Records                         │
│  → F. Scott Fitzgerald (People)         │
│  + Add Link                             │
└─────────────────────────────────────────┘
```

- Each field renders with an appropriate input widget (text field, checkbox,
  date picker, dropdown for select, etc.)
- `content` shows as a multi-line text area labeled "Notes"
- Linked records shown at the bottom with tap-to-navigate

### Schema Editor

Accessed via [+ Field] button or a "Manage Fields" option. Simple list of
fields with type, name, and drag-to-reorder.

```
┌─────────────────────────────────────────┐
│  Fields for "Books"          [+ Add]    │
├─────────────────────────────────────────┤
│  ≡  Title        text                   │
│  ≡  Author       text                   │
│  ≡  Status       select                 │
│  ≡  Rating       number                 │
│  ≡  Author Link  relation → People      │
└─────────────────────────────────────────┘
```

- Tap a field → edit name, type, config (e.g. select options)
- Drag handle (≡) for reordering
- Delete with swipe or long-press

### Widget Tree (Flutter)

```
MaterialApp
 └─ Scaffold
     ├─ Drawer → DatabaseListDrawer
     │    ├─ DatabaseListTile (per database)
     │    └─ CreateDatabaseTile
     └─ Body → DatabaseViewScreen
          ├─ AppBar (name, view switcher, + field)
          ├─ SearchBar
          └─ ViewSwitcher (switches between view widgets)
               ├─ CardView → ListView of RecordCard
               └─ NoteView → ListView of RecordNote

RecordDetailScreen (pushed on nav stack)
 ├─ FieldEditorList (one widget per field)
 ├─ ContentEditor (plain text area)
 └─ LinkedRecordsList

SchemaEditorScreen (pushed on nav stack)
 └─ ReorderableListView of FieldEditorTile
```

### Future Views (not in MVP, but schema supports them)

- **Table view**: Spreadsheet-style grid, one row per record, columns = fields
- **Gallery view**: Image-forward cards (when file/image field type is added)
- **Calendar view**: Records plotted on calendar by their date field
- **Kanban view**: Cards grouped into columns by a select field
