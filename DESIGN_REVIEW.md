# Lifelog — Solo Design Review

**Date:** 2026-02-26 (refresh pass — original: 2026-02-25)
**Reviewer:** Claude
**Scope:** Full codebase audit — journal screen, search screen, all record widgets, theme system

---

## App Summary

Lifelog is a keyboard-centric, infinite-scroll journal with a Swiss-Italian aesthetic. Records live in a flat list per day; types include text, heading, todo, bullet list, and habit. Auto-save is debounced at 500ms. Navigation between records and days is keyboard-driven (arrow keys). Search uses FTS5 with optional date-range filtering.

---

## Findings Triage

### 🟢 Fixed (since original review)

| ID | Title | Commit |
|----|-------|--------|
| C1 | No UI to create non-text record types | `3919fd2`, `638cf8c` |
| C2 | Search results silently read-only but look editable | `3919fd2` |
| C3 | No error handling on database writes | `3919fd2` |

---

### 🔴 Critical — Must fix before launch

*No new critical findings in this pass. C1–C3 are resolved.*

---

### 🟡 Major — Significant UX impact

---

### M1: No empty state or onboarding

**Files:** `record_section.dart:136–145`, `record_text_field.dart:199–207`
**Persona:** Naive User

On first launch, the user sees today's date header above a blank, borderless text input with no hint text or explanation. `RecordTextField.build()` constructs its `InputDecoration` with all borders set to `InputBorder.none` and no `hintText`. Nothing communicates:
- What types of content they can create
- That records auto-save
- That records auto-delete when empty
- How to navigate between days

**Recommendation:** Add `hintText` to `RecordTextField`'s decoration (e.g., "Write something, or type / for commands…"). For first-run, a brief inline coach mark or tooltip.

---

### M2: No save feedback — users can't tell if data persisted

**File:** `journal_screen.dart:90–106`
**Persona:** Naive User + Business Owner

The 500ms debounce save has zero UI feedback. A user typing, then immediately backgrounding the app, could lose the trailing keystrokes. Users with data-loss anxiety have no reassurance signal.

**Recommendation:** A subtle "Saved" indicator — even a fading dot or status text in the date header — gives confidence without cluttering the minimalist design.

---

### M3: Arrow navigation silently fails at unloaded day boundaries

**File:** `journal_screen.dart:38–46`
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

**File:** `lifelog_theme.dart:196–197`, `habit_record_widget.dart:98–115`
**Persona:** Skeptical Engineer + Accessibility

```dart
materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
visualDensity: VisualDensity.compact,
```

Both the todo checkbox and habit completion circle have sub-minimum touch targets. The checkbox is constrained to `GridConstants.checkboxSize` (20px) with shrink-wrap tap target. The habit `GestureDetector` wraps `SizedBox(width: 20, height: 28)`. The HIG (iOS) and Material guidelines both specify a minimum 44×44 pt interactive area. On mobile, both will be difficult to hit accurately.

**Recommendation:** Remove `MaterialTapTargetSize.shrinkWrap` from the checkbox theme, or increase `checkboxSize`. Wrap the habit circle `GestureDetector` in a minimum 44×44 `SizedBox` or use `InkWell` with `customBorder`.

---

### M6: Habit completion always targets today, not the viewed day

**File:** `habit_record_widget.dart:36–71`
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

A habit record appears on every day in the infinite scroll (because it's stored with a specific `record.date`). When a user views a past day and taps the habit circle, it marks **today** complete, not the past day they're looking at. Retroactive journaling is impossible.

**Recommendation:** Pass `record.date` to `_toggleCompletion` and toggle completions for that date. Update `_isCompletedToday` to check `record.date` rather than `DateService.today()`.

---

### M7: FAB obscures bottom record on small screens

**File:** `journal_screen.dart:140–150`
**Persona:** Naive User

The `FloatingActionButton.small` in the bottom-right overlaps the last visible record. `SafeArea` handles system insets, but the FAB itself (with margins) can cover content on small screens. The journal is the primary writing surface — obscuring it is a direct usability hit.

**Recommendation:** Add `floatingActionButtonLocation: FloatingActionButtonLocation.endTop` to push the FAB to the top-right, or add bottom padding to the `CustomScrollView` equal to the FAB height + margin.

---

### 🔵 Minor / Polish

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

**File:** `record_text_field.dart:67–73`

```dart
void _handleFocusChange() {
  if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
    widget.onDelete(widget.record.id);
  }
}
```

Records vanish on focus-loss when empty. This is elegant in principle but surprising the first time it happens. A brief `SnackBar` with "Undo" would align with Material Design's destructive action pattern.

---

### P6: Habit streak calculation is O(n²) per build

**File:** `habit_record_widget.dart:41–57`

```dart
int get _currentStreak {
  ...
  for (int i = 0; i < completions.length; i++) {
    if (completions.contains(checkDate)) {  // O(n) scan inside O(n) loop
```

`_currentStreak` iterates up to `completions.length` times, with a `List.contains` call (O(n)) on each iteration — total O(n²). For users with hundreds of completions, this runs on every `build()`. Convert `completions` to a `Set<String>` first to reduce to O(n), and cache the streak value to avoid recomputing on each rebuild.

---

### P7: `SEARCH` AppBar title is redundant

**File:** `search_screen.dart:114`

The AppBar title says "SEARCH" while the primary element below is a search input with a search icon prefix. The title adds no information. Consider replacing it with the app name or removing it, following the pattern of Gmail/Notion where the search bar IS the header.

---

### P8: Search shows blank view instead of prompt when no query entered

**File:** `search_screen.dart:226–234`

```dart
: _results.isEmpty && _queryController.text.isNotEmpty
    ? Center(child: Text('No results'))
    : ListView.builder(itemCount: dates.length, ...)  // 0 items when no query
```

When the screen opens with no query, `_results` is empty and `_queryController.text.isEmpty`, so it falls through to a zero-item `ListView`. The user sees a blank area. "Start typing to search…" would set clearer expectations and reduce the appearance of a broken screen.

---

### P9: Loading spinner fires on every keystroke, not on query dispatch

**File:** `search_screen.dart:49`

```dart
setState(() => _isSearching = true);  // fires immediately on any keystroke
_searchDebouncer.call(() async { ... });  // actual query deferred 500ms
```

`_isSearching` becomes `true` on every character typed, so the spinner appears and disappears 500ms after each keystroke — even when the user is mid-word. A more accurate signal: set `_isSearching = true` only inside the debouncer callback immediately before the async query.

---

### P10: `sectionType` is dead code in navigation notifications

**File:** `navigation_notifications.dart:12,28`, `keyboard_service.dart:60,68`, `journal_screen.dart:38–46`

`NavigateDownNotification` and `NavigateUpNotification` carry a `sectionType` field. In `KeyboardService`, it is hardcoded to `'records'` on every dispatch. In `_navigateDown` / `_navigateUp`, it is received as a parameter but never used. This is vestigial scaffolding from a planned multi-section design. Remove the field or document the intended extension point.

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
| Touch target size | ❌ | Checkbox (20px) and habit circle (20×28) both below 44×44 minimum (M5) |
| Text styles | ⚠️ | `bodyLarge` == `bodyMedium` (see P4) |
| Brand voice | ✅ | "TODAY · WEDNESDAY 25 FEB" style consistent |
| Record deletion | ✅ | Auto-delete on blur in journal; correctly suppressed (readOnly=true) in search |
| Empty states | ⚠️ | Search no-query state is blank; journal placeholder has no hint text (M1, P8) |

---

## Summary Table

| ID | Severity | Status | Title |
|----|----------|--------|-------|
| C1 | 🔴 Critical | ✅ Fixed | No UI to create non-text record types |
| C2 | 🔴 Critical | ✅ Fixed | Search results silently read-only but look editable |
| C3 | 🔴 Critical | ✅ Fixed | No error handling on database writes |
| M1 | 🟡 Major | 🔴 Open | No empty state or onboarding hint |
| M2 | 🟡 Major | 🔴 Open | No save feedback |
| M3 | 🟡 Major | 🔴 Open | Arrow navigation silently fails at unloaded day boundaries |
| M4 | 🟡 Major | 🔴 Open | Search results not sorted by date |
| M5 | 🟡 Major | 🔴 Open | Checkbox and habit circle touch targets below 44×44 px |
| M6 | 🟡 Major | 🔴 Open | Habit completion targets today, not the viewed day |
| M7 | 🟡 Major | 🔴 Open | FAB obscures bottom content |
| P1 | 🔵 Minor | 🔴 Open | Date filter label shows raw ISO format |
| P2 | 🔵 Minor | 🔴 Open | No loading state in DaySection |
| P3 | 🔵 Minor | 🔴 Open | Checked todo strikethrough contrast |
| P4 | 🔵 Minor | 🔴 Open | `bodyLarge` and `bodyMedium` are identical |
| P5 | 🔵 Minor | 🔴 Open | No undo for auto-deleted records |
| P6 | 🔵 Minor | 🔴 Open | Habit streak O(n²) per build |
| P7 | 🔵 Minor | 🔴 Open | "SEARCH" AppBar title is redundant |
| P8 | 🔵 Minor | 🔴 Open | Search blank view instead of prompt when no query entered |
| P9 | 🔵 Minor | 🔴 Open | Loading spinner fires on keystroke, not on query dispatch |
| P10 | 🔵 Minor | 🔴 Open | `sectionType` is dead code in navigation notifications |
