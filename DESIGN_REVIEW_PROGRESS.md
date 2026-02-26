# Design Review — Progress Tracker

**Last updated:** 2026-02-26
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

## 🔴 Major — Open

| ID | Title |
|----|-------|
| M1 | No empty state or onboarding hint |
| M2 | No save feedback |
| M3 | Arrow navigation silently fails at unloaded day boundaries |
| M4 | Search results not sorted by date |
| M5 | Checkbox and habit circle touch targets below 44×44 px |
| M6 | Habit completion targets today, not the viewed day |
| M7 | FAB obscures bottom content |

---

## 🔵 Minor — Open

| ID | Title | New? |
|----|-------|------|
| P1 | Date filter label shows raw ISO format | |
| P2 | No loading state in DaySection | |
| P3 | Checked todo strikethrough contrast | |
| P4 | `bodyLarge` and `bodyMedium` are identical | |
| P5 | No undo for auto-deleted records | |
| P6 | Habit streak O(n²) per build (worse than originally noted as O(n)) | |
| P7 | "SEARCH" AppBar title is redundant | |
| P8 | Search blank view instead of prompt when no query entered | ✨ New |
| P9 | Loading spinner fires on keystroke, not on query dispatch | ✨ New |
| P10 | `sectionType` is dead code in navigation notifications | ✨ New |
