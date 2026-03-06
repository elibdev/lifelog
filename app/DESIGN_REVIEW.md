# Design Review: Lifelog App

**Date:** 2026-03-06
**Scope:** `app/` directory — all screens, widgets, models, and navigation
**Method:** Golden screenshot audit + code review following the Solo Design Review Guide

---

## Executive Summary

The app has a solid foundation: clean adaptive layout, three useful view types, proper auto-save on the record detail screen, and good use of Material 3 theming with light/dark support. However, there are significant gaps in **feedback loops**, **error handling**, **input validation**, and **navigation edge cases** that would frustrate real users.

---

## Critical — Must Fix Before Launch

### C1. No Error Handling on Any Database Operation

**Where:** Every screen — `DatabaseViewScreen`, `RecordDetailScreen`, `SchemaEditorScreen`, `DatabaseListPanel`

**Problem:** All repository calls (`_repo.save()`, `_repo.delete()`, `_loadData()`, etc.) are `await`ed with no `try/catch`. If SQLite throws (disk full, corrupt DB, concurrent write conflict), the app crashes silently. The user loses context with no explanation.

**Impact:** Data loss, unrecoverable crashes, user abandonment.

**Fix:** Wrap all repository calls in try/catch. Show a `SnackBar` with human-readable error messages (e.g., "Couldn't save your changes. Please try again."). For load failures, show an error state with a retry button instead of an infinite spinner or blank screen.

---

### C2. No Save Feedback — User Never Knows If Data Persisted

**Where:** `RecordDetailScreen` — auto-save on back via `PopScope`

**Problem:** When the user presses back, `_save()` fires silently in `onPopInvokedWithResult`. There's no toast, no snackbar, no visual indicator. The user has zero confirmation that their edits were saved. This violates the "never leave the user wondering if the app froze" principle.

Additionally, `onPopInvokedWithResult` fires *during* the pop — if `_save()` fails, the user has already navigated away and has no idea their data was lost.

**Impact:** User anxiety about data safety. Silent data loss on save failure.

**Fix:**
- Add a brief `SnackBar` ("Saved") after successful save, or use a subtle auto-save indicator (like a checkmark that appears briefly).
- For NoteView's inline debounced save, show a small "Saving..." / "Saved" indicator.
- If save fails, block navigation and show an error dialog.

---

### C3. Number Field Accepts Non-Numeric Input

**Where:** `RecordDetailScreen._buildFieldEditor` — `FieldType.number` case (line 210-217)

**Problem:** The number field sets `keyboardType: TextInputType.number` (which only affects soft keyboards on mobile), but has no `inputFormatters`. On desktop or with a hardware keyboard, users can type letters, symbols, or paste arbitrary text into a "number" field. This data silently gets stored as a string.

**Impact:** Corrupted data, broken sorting/filtering assumptions, confusing behavior when the value displays as "abc" in a number column.

**Fix:** Add `inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]` to restrict input to valid numeric characters.

---

### C4. Narrow Layout Stacks Duplicate Routes on Database Switch

**Where:** `_NarrowLayout.didUpdateWidget` (main.dart, line 175-185)

**Problem:** When a user selects Database A, then taps Database B from the list, `didUpdateWidget` pushes a *new* `DatabaseViewScreen` on top of the existing one. The back stack becomes: `List → DB_A → DB_B`. Pressing back from DB_B takes the user to DB_A (stale), not back to the list. Switching between 5 databases creates a 5-deep stack.

**Impact:** Confusing back-button behavior. Users expect "back" to return to the database list.

**Fix:** Before pushing, pop back to the root route first: `_navigatorKey.currentState?.popUntil((route) => route.isFirst)` then push. Or use `pushReplacement` instead of `push`.

---

## Major — Significant UX Impact

### M1. Record Detail Title is Generic "Record"

**Where:** `RecordDetailScreen` AppBar (line 121)

**Problem:** The AppBar shows "Record" for every record in every database. When a user has a book called "The Great Gatsby" open, the header says "Record" — zero useful context. This is especially disorienting when navigating back and forth.

**Fix:** Display the first text field value as the title (e.g., the "Title" field), falling back to the database name, falling back to "New Record" for empty records.

---

### M2. Delete Actions Have No Danger Styling

**Where:** `RecordDetailScreen._deleteRecord` and `SchemaEditorScreen._deleteField`

**Problem:** The "Delete" button in confirmation dialogs is a plain `TextButton` with default text styling. It looks identical to "Cancel". There's no red/destructive color to signal that this is a permanent, irreversible action.

**Impact:** Users may tap Delete accidentally, especially since it's on the right (the "primary action" position in LTR layouts).

**Fix:** Style the Delete button with `TextButton(style: TextButton.styleFrom(foregroundColor: colorScheme.error))`. Consider also making the delete icon button in the AppBar use `error` color.

---

### M3. No Way to Rename or Delete a Database

**Where:** `DatabaseListPanel`

**Problem:** Users can create databases but cannot rename or delete them. There's no long-press menu, no swipe-to-delete, no edit button. A typo in the database name is permanent.

**Impact:** Users accumulate test/typo databases with no cleanup path. Forces workarounds (creating new DB, manually recreating all fields/records).

**Fix:** Add a long-press context menu or trailing icon menu on each database list item with "Rename" and "Delete" options. Delete should warn about cascading data loss.

---

### M4. No Search or Filter Capability

**Where:** `DatabaseViewScreen` — all three view types

**Problem:** Despite the database having FTS5 full-text search indexed (`records_fts` table) and a `search()` method on `RecordRepository`, there's no search bar or filter UI anywhere. Users with 50+ records have no way to find a specific one except scrolling.

**Impact:** App becomes unusable at moderate data scale. The search infrastructure exists in the backend but is completely unexposed.

**Fix:** Add a search bar (or search icon that expands into one) to the `DatabaseViewScreen` AppBar. Use the existing `RecordRepository.search()` method.

---

### M5. Date Picker Ignores Existing Value

**Where:** `RecordDetailScreen._buildFieldEditor` — `FieldType.date` case (line 231-243)

**Problem:** The date picker always opens to `DateTime.now()` regardless of whether the field already has a date set. If a user previously set "2024-01-15" and taps to edit, the picker opens to today's date, forcing them to scroll back.

**Fix:** Parse the existing ISO date string and use it as `initialDate`:
```dart
final existing = _record.getValue(field.id, '') as String?;
final initialDate = existing != null && existing.isNotEmpty
    ? DateTime.tryParse(existing) ?? DateTime.now()
    : DateTime.now();
```

---

### M6. Select Field Cannot Be Cleared

**Where:** `RecordDetailScreen._buildFieldEditor` — `FieldType.select` case (line 244-256)

**Problem:** `DropdownButtonFormField` has no "None" or "Clear" option. Once a user selects a value, they can never deselect it. For optional fields (e.g., "Status" on a book that hasn't been started), this forces an incorrect value.

**Fix:** Prepend a `DropdownMenuItem(value: null, child: Text('None'))` to the items list, or add a clear button.

---

### M7. NoteView Expand Button is Below Touch Target Minimum

**Where:** `NoteView._NoteCard` (line 185-195)

**Problem:** The `open_in_full` IconButton is constrained to 28x28px. Material Design specifies a minimum touch target of 48x48dp (and Apple HIG says 44x44pt). This makes the button nearly impossible to hit accurately on mobile, especially next to the scrollable text field.

**Fix:** Remove the `SizedBox(width: 28, height: 28)` constraint. Let the IconButton use its default minimum size, or use `IconButton.styleFrom(minimumSize: Size(44, 44))`.

---

### M8. Relation Fields Are Non-Functional

**Where:** `RecordDetailScreen._buildFieldEditor` — `FieldType.relation` case (line 258-262)

**Problem:** The schema editor allows creating relation fields (with a target database picker), but the record detail shows only a static "Linked records" label with no interaction. Users can define a relation schema but never actually create links.

**Impact:** Feature appears broken. Users invest time setting up relation fields only to discover they don't work.

**Fix:** Either implement a basic link picker (show records from the target database, let user select), or hide the `relation` type from the schema editor field type dropdown until it's functional.

---

### M9. Schema Editor Shows No Loading State

**Where:** `SchemaEditorScreen` (line 128)

**Problem:** Unlike `DatabaseViewScreen` which shows a `CircularProgressIndicator` during load, the schema editor jumps directly from empty to populated. On slow devices or large schemas, the user briefly sees "No fields defined yet" before fields appear, which could trigger an "Add Field" tap on the wrong screen state.

**Fix:** Add a `_loading` boolean and show a spinner while `_loadFields()` is in progress.

---

## Minor / Polish

### P1. Card View Shows Checkbox Only When True

**Where:** `CardView._formatValue` (line 117)

Unchecked checkboxes return empty string and get filtered out. Users can't distinguish "field not set" from "field is unchecked." Show an empty checkbox icon (like TableView does) for `false` values.

---

### P2. Table View "Fa..." Truncated Column Header

**Where:** Golden `narrow_table_phone.png`

On phone width, the rightmost column header gets clipped (showing "Fa..." for "Favorite"). While horizontal scroll handles this, the initial view gives no indication there's more content to the right. Consider adding a visual scroll indicator or making the first column sticky.

---

### P3. Empty Database on Wide Layout Missing "No Records" Message

**Where:** Golden `wide_empty_detail_desktop.png`

The wide layout empty state for a database with no records shows only the header bar and a blank area. The "No records yet" + "Add Record" button appears to not render (or renders too small to see). Verify the empty state renders correctly in the wide layout.

---

### P4. View Switcher Dropdown is Not Very Discoverable

**Where:** `DatabaseViewScreen` AppBar

The plain text dropdown ("Card", "Note", "Table") doesn't visually suggest it's a view toggle. A `SegmentedButton` would be more discoverable and tactile, making it obvious that these are view modes. The current dropdown looks like it could be a filter or sort option.

---

### P5. Inconsistent Branding Between Layouts

**Where:** `main.dart` — narrow vs wide layout

- Narrow: AppBar shows "Lifelog" title, body has "Databases" header
- Wide: No app title, left panel shows "Databases" header only

The app name "Lifelog" only appears in the narrow layout. Wide-layout users never see the app name.

---

### P6. No Confirmation When Leaving Unsaved NoteView Edits

**Where:** `NoteView._NoteCard` — debounced save with 800ms delay

If a user edits a note inline and immediately taps the expand button (or navigates away) within 800ms, the pending save may be lost. The `_flushSave()` in `dispose()` calls `widget.onRecordUpdated` but the parent widget may already be unmounted or navigating.

---

### P7. Field Dialog Allows Changing Field Type on Edit

**Where:** `SchemaEditorScreen._FieldDialog` (line 229-238)

Editing an existing field allows changing its type (e.g., from `text` to `checkbox`). This silently breaks existing record data — text values don't map to booleans. Either disable the type dropdown on edit, or warn the user and offer to clear existing data.

---

### P8. Database Creation Dialog Accepts Empty/Whitespace Names

**Where:** `DatabaseListPanel._CreateDatabaseDialog`

The "Create" button calls `Navigator.pop(context, _controller.text)` without validation. While the parent checks `name.trim().isEmpty`, the dialog itself gives no feedback — the user taps "Create" with spaces, nothing happens, and there's no error message explaining why.

---

### P9. No Reorder Capability for Records

**Where:** All three view types

Records have an `orderPosition` field but there's no drag-to-reorder UI (unlike the schema editor, which uses `ReorderableListView`). Records can only be viewed in creation order.

---

### P10. AppBar Back Button on Wide Layout

**Where:** `DatabaseViewScreen` in wide layout

When viewing a record detail (pushed from `DatabaseViewScreen`), the record detail screen's back arrow navigates correctly. But on wide layout, the `DatabaseViewScreen` itself shows a back arrow (from the nested Scaffold), which is confusing in the master-detail context since there's nowhere to "go back" to — the list is already visible.

---

## Summary Table

| Severity | Count | Key Themes |
|----------|-------|------------|
| Critical | 4 | Error handling, save feedback, input validation, navigation |
| Major | 9 | Missing features, broken features, accessibility, discoverability |
| Minor | 10 | Visual polish, consistency, edge cases |

**Top 3 Priorities:**
1. **Add error handling** (C1) — crashes are unacceptable
2. **Fix navigation stacking** (C4) — broken back button kills trust
3. **Add save feedback** (C2) — users need to know their data is safe
