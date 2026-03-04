# Design Review — Progress Tracker

**Last updated:** 2026-03-01
**Source review:** [DESIGN_REVIEW.md](DESIGN_REVIEW.md)

---

## 🟢 Fixed

### C1 — No UI to create non-text record types
**Status:** ✅ Fixed

**Done (commit `3919fd2`):** Typing `/todo`, `/h1`, `/h2`, `/h3`, `/bullet`, or `/habit` in any text record converts it to the target type. A `RefocusRecordNotification` restores keyboard focus after the widget tree rebuilds. Habit records now accept a name via `RecordTextField` (mapped to `habit.name` metadata).

**Done (commit `638cf8c`):** A `+` icon button in the leading gutter of every text record opens a `PopupMenuButton` with all five record types. Selecting a type converts the record in-place, preserving content (text → habit moves content to `habit.name`). `RefocusRecordNotification` restores focus after the rebuild, mirroring the slash-command pattern. Hidden in `readOnly` contexts (search results).

Both entry points coexist: slash commands for keyboard-first users; the `+` picker for pointer/touch users.

**Files:** `record_section.dart`, `record_text_field.dart`, `notifications/navigation_notifications.dart`, `text_record_widget.dart`

---

### C2 — Search results silently read-only but look editable
**Status:** ✅ Fixed (commit `3919fd2`)

`AdaptiveRecordWidget` gained a `readOnly` flag threaded through all 5 sub-widgets and `RecordTextField`. `TextField.readOnly = true` prevents editing; checkbox and habit toggle are disabled; auto-delete on blur is suppressed. `search_screen.dart` passes `readOnly: true`.

**Files:** `adaptive_record_widget.dart`, `text_record_widget.dart`, `heading_record_widget.dart`, `bullet_list_record_widget.dart`, `todo_record_widget.dart`, `habit_record_widget.dart`, `record_text_field.dart`, `search_screen.dart`

---

### C3 — No error handling on database writes
**Status:** ✅ Fixed (commit `3919fd2`)

Both the save and delete paths are now wrapped in `try/catch`. On failure a `SnackBar` is shown.

**Files:** `journal_screen.dart`, `record_section.dart`

---

### M1 — No empty state or onboarding hint
**Status:** ✅ Fixed (commit `40cd3c9`)

`RecordTextField`'s `InputDecoration` now includes `hintText: 'Write, or type / for commands…'`. Hint is suppressed in `readOnly` mode (search results) where it would be misleading. This surfaces the slash-command system passively without adding a modal coach mark.

**Files:** `record_text_field.dart`

---

### M2 — No save feedback
**Status:** ✅ Fixed (commit `c8a324e`)

After each debounced write succeeds, `_flashSaved()` sets `_showSaved = true` for 1.5 s. An `AnimatedOpacity` "Saved" badge renders at the bottom-center of the journal screen, fading in/out without interrupting the writing flow. The badge is always in the widget tree (opacity 0 when hidden) so the AnimatedOpacity fade-out plays correctly.

**Files:** `journal_screen.dart`

---

### M3 — Arrow navigation silently fails at unloaded day boundaries
**Status:** ✅ Fixed (commit `c8a324e`)

`_navigateDown` / `_navigateUp` now check `currentState != null` first. If the target `DaySection` hasn't rendered yet, they: (1) pre-load the date's records into cache via `_getRecordsForDate`, (2) call `setState` to trigger a rebuild that may bring the section into view, (3) add a `postFrameCallback` to retry focus once the frame settles. This handles the common adjacent-day case; deeply off-screen days would require scroll-to, which remains a future improvement.

**Files:** `journal_screen.dart`

---

### M4 — Search results not sorted by date
**Status:** ✅ Fixed (commit `1ee2a9d`)

`_groupByDate` result keys are now sorted descending with `..sort((a, b) => b.compareTo(a))` before building the `ListView`, so most-recent matches appear first regardless of SQLite return order.

**Files:** `search_screen.dart`

---

### M5 — Checkbox and habit circle touch targets below 44×44 px
**Status:** ✅ Fixed (commits `5d49db2`, `1bc9d07`)

- **Habit circle:** Replaced `SizedBox(20, 20)` + `GestureDetector` with `SizedBox(44, 44)` + `GestureDetector` + centered `Icon`. Full 44×44 px tap area with 20px visual icon.
- **Checkbox:** Removed `SizedBox(20, 20)` constraint around `Checkbox` in `TodoRecordWidget`. Changed `checkboxTheme.materialTapTargetSize` from `shrinkWrap` to `padded` in both light and dark themes, restoring Flutter's default 48×48 accessible tap area.

**Files:** `habit_record_widget.dart`, `todo_record_widget.dart`, `lifelog_theme.dart`

---

### M6 — Habit completion targets today, not the viewed day
**Status:** ✅ Fixed (commit `5d49db2`)

`_isCompletedForDate` and `_toggleCompletion` now use `record.date` instead of `DateService.today()`. Viewing a past day and tapping the habit circle now correctly toggles that day's completion, enabling retroactive journaling.

**Files:** `habit_record_widget.dart`

---

### M7 — FAB obscures bottom content
**Status:** ✅ Fixed (commit `c8a324e`)

`Scaffold.floatingActionButtonLocation` set to `FloatingActionButtonLocation.miniEndTop`, moving the search FAB to the top-right corner of the body. The writing surface at the bottom is now fully accessible.

**Files:** `journal_screen.dart`

---

### P1 — Date filter label shows raw ISO format
**Status:** ✅ Fixed (commit `1ee2a9d`)

Date filter badge now uses `DateService.formatForDisplay()` for both start and end dates, producing human-readable output (e.g. "Thursday, January 1 — Saturday, January 31") instead of raw ISO strings.

**Files:** `search_screen.dart`

---

### P2 — No loading state in DaySection
**Status:** ✅ Fixed (commit `59c4c24`)

`FutureBuilder` now checks `ConnectionState.waiting` and renders a compact `CircularProgressIndicator` (16×16, 1.5px stroke) inline while the DB query runs. Eliminates the flash-of-empty-content on slower devices.

**Files:** `day_section.dart`

---

### P3 — Checked todo strikethrough contrast
**Status:** ✅ Fixed (commit `1bc9d07`)

Checked todo text now renders in `colorScheme.outline` (#8A8A8A), matching the strikethrough color. This makes the strikethrough visually distinct against the muted text rather than overlapping full-opacity ink.

**Files:** `todo_record_widget.dart`

---

### P4 — `bodyLarge` and `bodyMedium` are identical
**Status:** ✅ Fixed (commit `1bc9d07`)

`bodyLarge` font size raised from 15px to 17px in `_buildTextTheme`. The two styles are now semantically distinct: `bodyMedium` for standard record content (15px), `bodyLarge` for promoted content like "No results found" (17px).

**Files:** `lifelog_theme.dart`

---

### P5 — No undo for auto-deleted empty records
**Status:** ✅ Fixed (commit `bffdf88`)

`_handleFocusChange` in `RecordTextField` now captures `record` and `onSave` before calling `onDelete`, then shows a 3-second `SnackBar` with an "Undo" action. Pressing "Undo" calls `onSave(record)`, re-creating the empty record through the normal debounced save path. Callbacks are captured before widget disposal, so the closure is safe to invoke from the SnackBar action.

**Files:** `record_text_field.dart`

---

### P6 — Habit streak O(n²) per build
**Status:** ✅ Fixed (commit `5d49db2`)

`_currentStreak` now converts `habitCompletions` to `Set<String>` upfront, reducing `contains()` from O(n) to O(1). The `for` loop was replaced with a `while` loop, removing the unused loop variable. Total complexity: O(n) instead of O(n²).

**Files:** `habit_record_widget.dart`

---

### P7 — "SEARCH" AppBar title is redundant
**Status:** ✅ Fixed (commit `1ee2a9d`)

`AppBar.title` removed from `SearchScreen`. The search field with search-icon prefix already establishes context; the label above it was redundant.

**Files:** `search_screen.dart`

---

### P8 — Search blank view instead of prompt when no query entered
**Status:** ✅ Fixed (commit `1ee2a9d`)

When `_queryController.text.isEmpty`, the `Expanded` child now shows `Center(Text('Start typing to search…'))` instead of a zero-item `ListView`. The ternary chain: `_isSearching` → empty query prompt → no-results text → results list.

**Files:** `search_screen.dart`

---

### P9 — Loading spinner fires on keystroke, not on query dispatch
**Status:** ✅ Fixed (commit `1ee2a9d`)

`setState(() => _isSearching = true)` moved inside the `_searchDebouncer.call()` callback. The spinner now appears only after the 500ms debounce fires (query actually dispatched), not on every keystroke. `_searchDebouncer.cancel()` is also called when the query is cleared, preventing stale spinner state.

**Files:** `search_screen.dart`

---

### P10 — `sectionType` is dead code in navigation notifications
**Status:** ✅ Fixed (commit `6d327b8`)

`sectionType: String` field removed from `NavigateDownNotification` and `NavigateUpNotification`. All dispatch sites in `KeyboardService` updated (removed `sectionType: 'records'`). Handler signatures in `JournalScreen._navigateDown/_navigateUp` simplified accordingly.

**Files:** `navigation_notifications.dart`, `keyboard_service.dart`, `journal_screen.dart`

---

## Summary

All 17 findings (C1–C3, M1–M7, P1–P10) are now resolved. ✅
