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

### Dart Models

```
AppDatabase        – id, name, orderPosition, createdAt, updatedAt
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
