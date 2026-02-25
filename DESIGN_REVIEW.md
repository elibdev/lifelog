# Lifelog — Solo Design Review

**Date:** 2026-02-25
**Reviewer:** Claude
**Scope:** Full codebase audit — journal screen, search screen, all record widgets, theme system

---

## App Summary

Lifelog is a keyboard-centric, infinite-scroll journal with a Swiss-Italian aesthetic. Records live in a flat list per day; types include text, heading, todo, bullet list, and habit. Auto-save is debounced at 500ms. Navigation between records and days is keyboard-driven (arrow keys). Search uses FTS5 with optional date-range filtering.

---

## Findings Triage

### 🔴 Critical — Must fix before launch

---

### C1: No UI to create non-text record types

**Files:** `record_section.dart:111`, `keyboard_service.dart`
**Persona:** Naive User + Business Owner

`_handleEnterPressed` always creates `RecordType.text`:

```dart
final newRecord = Record(
  type: RecordType.text,  // hardcoded — no way to choose
  ...
);
```

`AdaptiveRecordWidget`, `TodoRecordWidget`, `HabitRecordWidget`, etc. all render correctly — but there is **no mechanism in the UI to create them**. A user cannot create a todo, heading, bullet list, or habit from the journal. `KeyboardService` handles `Ctrl+Enter` to toggle a todo checkbox, but you can't get a todo record to exist in the first place.

The entire record-type system is invisible to users. This is a feature completeness issue that makes the app effectively a plain text editor.

**Recommendation:** Inline type commands (e.g., `/todo`, `/h1`) on empty records, or a type-picker toolbar that appears on focus.

---

### C2: Search results are silently read-only

**File:** `search_screen.dart:292–294`
**Persona:** Skeptical Engineer + Naive User

```dart
AdaptiveRecordWidget(
  record: record,
  onSave: (_) {},    // changes discarded
  onDelete: (_) {},  // deletes discarded
)
```

Record widgets in search are fully interactive — they render editable `TextField` inputs — but changes are silently dropped. A user who edits a search result and navigates away loses their edits with no warning. Worse, if the empty-field auto-delete fires (focus loss on empty text), the deletion is also silently swallowed, so the DB record survives but the user expects deletion.

**Recommendation:** Either make search results visually read-only (non-editable display, no cursor) or wire up real `onSave`/`onDelete` with the repository.

---

### C3: No error handling on database writes

**File:** `journal_screen.dart:77–95`, `record_section.dart:83–88`
**Persona:** Skeptical Engineer

```dart
debouncer.call(() async {
  await _repository.saveRecord(record);  // no try/catch
});
```

If SQLite throws (disk full, corruption, permission error), the in-memory state reflects the "saved" record while the DB does not. Silent data divergence. No user feedback.

**Recommendation:** Wrap in try/catch, surface an error snackbar, and consider reverting in-memory state on failure.

---

## 🟡 Major — Significant UX impact

---

### M1: No empty state or onboarding

**File:** `record_section.dart:136–145`, `day_section.dart`
**Persona:** Naive User

On first launch, the user sees today's date header above a blank, borderless text input with no hint text or explanation. Nothing communicates:
- What types of content they can create
- That records auto-save
- That records auto-delete when empty
- How to navigate between days

The placeholder `Record` in `RecordSection` has `content: ''` and type `text` — the rendered `RecordTextField` has no `hintText` set.

**Recommendation:** Add `hintText` to the placeholder's `RecordTextField` (e.g., "Write something…"). For first-run, consider a brief inline tooltip or coach mark.

---

### M2: No save feedback — users can't tell if data persisted

**File:** `journal_screen.dart:90–94`
**Persona:** Naive User + Business Owner

The 500ms debounce save has zero UI feedback. A user typing, then immediately backgrounding the app, could lose the trailing keystrokes. More critically, users who are anxious about data loss have no reassurance signal.

**Recommendation:** A subtle "Saved" indicator — even a fading dot or status text in the date header — gives users confidence without cluttering the minimalist design.

---

### M3: Arrow navigation silently fails at unloaded day boundaries

**File:** `journal_screen.dart:38–46`, `record_section.dart:33–36`
**Persona:** Skeptical Engineer

```dart
void _navigateUp(String date, String sectionType) {
  final prevDate = DateService.getPreviousDate(date);
  _getSectionKey(prevDate).currentState?.focusLastRecord();
  // if currentState is null (day not yet rendered), nothing happens
}
```

When a user arrow-keys UP from the first record of day N, the code tries to focus day N−1's last record. But `DaySection` for day N−1 is only built when the user has scrolled to it. If it hasn't been rendered yet, `currentState` is null and the keypress is silently swallowed.

**Recommendation:** Trigger a scroll-to reveal the target day before attempting focus, or proactively pre-load one day above/below the current viewport.

---

### M4: Search results not sorted by date

**File:** `search_screen.dart:97–103`
**Persona:** Skeptical Engineer

```dart
Map<String, List<Record>> _groupByDate(List<Record> records) {
  final Map<String, List<Record>> grouped = {};
  for (final record in records) {
    grouped.putIfAbsent(record.date, () => []).add(record);
  }
  return grouped;  // insertion order = SQLite return order, not date order
}
```

The grouped map's key iteration order equals SQLite's return order, which is not guaranteed to be date-sorted. A search for "meeting" could show dates in arbitrary order.

**Recommendation:** Sort `dates` descending after grouping: `final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));`

---

### M5: Checkbox touch target below 44×44 px minimum

**File:** `lifelog_theme.dart:196–197`
**Persona:** Skeptical Engineer + Accessibility

```dart
materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
visualDensity: VisualDensity.compact,
```

The checkbox is sized at `GridConstants.checkboxSize` (20px) with shrink-wrap tap target. The HIG (iOS) and Material guidelines both specify a minimum 44×44 pt interactive area. On mobile, the checkbox will be difficult to hit accurately.

**Recommendation:** Remove `MaterialTapTargetSize.shrinkWrap`, or increase `checkboxSize`. The checkbox is wrapped in a `SizedBox(width: 20, height: 28)` in `TodoRecordWidget` which also constrains the effective tap area.

---

### M6: Habit completion always targets today, not the viewed day

**File:** `habit_record_widget.dart:31–51`
**Persona:** Skeptical Engineer + Naive User

```dart
bool get _isCompletedToday {
  final today = DateService.today();  // always today
  return record.habitCompletions.contains(today);
}

void _toggleCompletion() {
  final today = DateService.today();  // always today
  ...
}
```

A habit record appears on every day in the infinite scroll (because it's stored with a specific `record.date`). When a user views a past day and taps the habit circle, it marks **today** complete, not the past day they're looking at. Retroactive journaling — marking a habit as done on Monday when it's now Wednesday — is impossible.

**Recommendation:** Pass the `record.date` to `_toggleCompletion` and toggle completions for that date. The `_isCompletedToday` check should use `record.date` to show whether that day was completed.

---

### M7: FAB obscures bottom record on small screens

**File:** `journal_screen.dart:116–126`
**Persona:** Naive User

The `FloatingActionButton.small` in the bottom-right overlaps the last visible record when there's no bottom padding. `SafeArea` handles system insets, but the FAB itself (56×56 with margins) can cover content. The journal is the main writing surface — obscuring it is a direct usability hit.

**Recommendation:** Add `floatingActionButtonLocation: FloatingActionButtonLocation.endTop` to push the FAB to the top-right, or add bottom padding to the `CustomScrollView` equal to the FAB height + margin.

---

## 🔵 Minor / Polish

---

### P1: Date filter label shows raw ISO format

**File:** `search_screen.dart:205`

```dart
Text('$_startDate — $_endDate')  // "2026-01-01 — 2026-01-31"
```

The date filter badge shows machine-format dates. `DateService.formatForDisplay()` is available and would produce "WEDNESDAY 1 JAN — SATURDAY 31 JAN".

---

### P2: No loading state in `DaySection` while records load

**File:** `day_section.dart:33–37`

```dart
builder: (context, snapshot) {
  final records = snapshot.data ?? [];  // empty while loading
```

`FutureBuilder` shows an empty day section while the DB query runs. On slower devices, there's a visible flash of empty content before records appear. A `CircularProgressIndicator` inline with the date header (like search's loading state) would be more polished.

---

### P3: Checked todo strikethrough color could be more visible

**File:** `todo_record_widget.dart:77–80`

The strikethrough uses `theme.colorScheme.outline` (`#8A8A8A`) on text that is simultaneously faded with `Opacity(0.5)`. The combination can make the strikethrough hard to distinguish from plain faded text on some displays.

---

### P4: `bodyLarge` and `bodyMedium` are identical

**File:** `lifelog_theme.dart:90–104`

Both `bodyLarge` and `bodyMedium` are defined with `fontSize: 15`, `fontWeight: w400`, same tracking and line height. Having two identical styles is unused differentiation potential. Consider giving `bodyLarge` a slightly larger size or weight for semantic correctness, or consolidating to one.

---

### P5: No undo for auto-deleted empty records

**File:** `record_text_field.dart:63–66`

```dart
void _handleFocusChange() {
  if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
    widget.onDelete(widget.record.id);
  }
}
```

Records vanish on focus-loss when empty. This is elegant in principle but surprising the first time it happens. A brief `SnackBar` with "Undo" would align with Material Design's destructive action pattern.

---

### P6: Habit streak calculation runs on every build

**File:** `habit_record_widget.dart:36–52`

`_currentStreak` iterates all completions on each `build()`. For heavy users (hundreds of completions), this is O(n) work per render. Cache the streak value or compute it in the repository layer.

---

### P7: `SEARCH` AppBar title is redundant

**File:** `search_screen.dart:114`

The AppBar title says "SEARCH" while the primary element below is a search input with a search icon prefix. The title adds no information. Consider replacing it with the app name or removing it, following the pattern of Gmail/Notion where the search bar IS the header.

---

## Consistency Check

| Element | Consistent? | Notes |
|---------|-------------|-------|
| Day headers | ✅ | `titleMedium` everywhere |
| Dividers | ✅ | 0.5px rule throughout |
| Date formatting | ✅ | `DateService.formatForDisplay()` used consistently |
| Content padding | ✅ | `GridConstants.calculateContentLeftPadding()` used in all layouts |
| Back button placement | ✅ | Standard Navigator AppBar back button |
| Checkbox sizing | ✅ | `GridConstants.checkboxSize` shared |
| Text styles | ⚠️ | `bodyLarge` == `bodyMedium` (see P4) |
| Brand voice | ✅ | "TODAY · WEDNESDAY 25 FEB" style consistent |
| Record deletion | ⚠️ | Auto-delete on blur in journal; silently suppressed in search (see C2) |

---

## Summary Table

| ID | Severity | Title |
|----|----------|-------|
| C1 | 🔴 Critical | No UI to create non-text record types |
| C2 | 🔴 Critical | Search results silently read-only but look editable |
| C3 | 🔴 Critical | No error handling on database writes |
| M1 | 🟡 Major | No empty state or onboarding hint |
| M2 | 🟡 Major | No save feedback |
| M3 | 🟡 Major | Arrow navigation silently fails at unloaded day boundaries |
| M4 | 🟡 Major | Search results not sorted by date |
| M5 | 🟡 Major | Checkbox touch target below 44×44 px |
| M6 | 🟡 Major | Habit completion targets today, not the viewed day |
| M7 | 🟡 Major | FAB obscures bottom content |
| P1 | 🔵 Minor | Date filter label shows raw ISO format |
| P2 | 🔵 Minor | No loading state in DaySection |
| P3 | 🔵 Minor | Checked todo strikethrough contrast |
| P4 | 🔵 Minor | `bodyLarge` and `bodyMedium` are identical |
| P5 | 🔵 Minor | No undo for auto-deleted records |
| P6 | 🔵 Minor | Habit streak O(n) per build |
| P7 | 🔵 Minor | "SEARCH" AppBar title is redundant |
