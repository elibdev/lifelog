# Lifelog — Solo Design Review (Round 2)

**Date:** 2026-03-04
**Reviewer:** Claude
**Scope:** Full codebase audit — JournalScreen, SearchScreen, all record widgets, theme, interactions
**Flutter analyze:** No issues found

---

## Context

This is a second-pass design review. Round 1 identified 3 critical, 7 major, and 10 minor findings. All were addressed in commits `6d327b8` through `1348cbd`. This review re-evaluates the current state through fresh eyes and identifies new findings.

---

## Previous Findings — Status

All Round 1 findings have been addressed:

| ID | Title | Status |
|----|-------|--------|
| C1 | No UI to create non-text record types | Fixed (TypePickerButton + slash commands) |
| C2 | Search results silently read-only but look editable | Fixed (readOnly mode + hidden TypePicker) |
| C3 | No error handling on database writes | Fixed (SnackBar errors on save/delete failure) |
| M1 | No empty state or onboarding hint | Fixed (hint text: "Write, or type / for commands…") |
| M2 | No save feedback | Fixed ("Saved" badge, bottom-center, animated opacity) |
| M3 | Arrow navigation fails at unloaded day boundaries | Fixed (pre-load + post-frame retry) |
| M4 | Search results not sorted by date | Fixed (descending date sort) |
| M5 | Touch targets below minimum | Partially fixed (habit: 44px; todo: reverted to compact) |
| M6 | Habit completion targets today, not viewed day | Fixed (uses record.date) |
| M7 | FAB obscures bottom content | Fixed (moved to miniEndTop) |
| P1–P10 | Various polish items | All addressed |

---

## Round 2 Findings

### Step 1: The "Silent Run"

**Task:** Open the app. Create a heading, two todos, a bullet list, and a habit for today. Search for yesterday's entry. Navigate back.

**Micro-frustrations:**

1. Created a todo, checked it, then realized I misspelled the text. Had to uncheck, edit, recheck. No inline edit-while-checked.
2. Created a habit by typing `/habit`. Name was set from the content. Realized the name had a typo — **no way to edit it**. The habit uses a `Text` widget, not a `RecordTextField`.
3. Arrow keys moved me to the next record instead of moving my cursor to the next line in a multi-line note. Had to use the mouse to position within the text.
4. Found a search result. Tapped it — nothing happened. **No navigation from search results to the journal entry.**
5. Tried to reorder records (drag a todo above a heading). No drag handles, no reorder gesture. Only option: delete and recreate.

---

### Step 2: Logic Audit

#### Screen: JournalScreen

| Edge Case | Handled? | Notes |
|-----------|----------|-------|
| First launch (empty DB) | Yes | Placeholder per day with hint text |
| Save failure (disk full) | Yes | SnackBar with error message |
| Delete failure | Yes | SnackBar with error message |
| Rapid scrolling far into future | Partial | Unbounded SliverList; no practical limit on day count |
| App backgrounded mid-type | Partial | Debouncer may not fire if app is killed before 500ms elapses |
| Rotate device | Partial | Today anchor preserved, but scroll offset within the day resets |

#### Screen: SearchScreen

| Edge Case | Handled? | Notes |
|-----------|----------|-------|
| Empty query | Yes | "Start typing to search…" prompt |
| No results | Yes | "No results found" message |
| FTS5 special characters (`*`, `"`, `NEAR`) | No | Could cause query syntax errors |
| Date range with no results | Partial | "No results found" shown, but the active date filter isn't called out as the likely cause |
| Clear search then re-search | Yes | Clear button resets properly |

#### Widget: HabitRecordWidget

| Edge Case | Handled? | Notes |
|-----------|----------|-------|
| Edit habit name after creation | **No** | Uses `Text` widget — name is frozen after creation |
| Delete a habit | Partial | Only via TypePickerButton conversion, which loses completion data |
| Habit with 500+ completions | Yes | Set-based O(1) lookup for streak (fixed in round 1) |
| Undo habit completion | Yes | Tap again to un-complete |

#### Widget: RecordTextField

| Edge Case | Handled? | Notes |
|-----------|----------|-------|
| Very long single record (10k+ chars) | Partial | No length limit; performance may degrade |
| Paste large clipboard | Partial | No max-length guard |
| Concurrent edits to same record | No | No conflict detection (acceptable for single-device app) |

---

### Step 3: Consistency Check

| Element | Consistent? | Notes |
|---------|-------------|-------|
| Day headers | Yes | `titleMedium` (12px, w500, 1.2 tracking) used everywhere |
| Content padding | Yes | `GridConstants.calculateContentLeftPadding()` used in all layouts |
| Touch target sizes | **No** | Habit: 44×44. Todo checkbox: 20×20 (reverted to compact). TypePickerButton: ~30×28 |
| Record vertical spacing | Yes | `itemVerticalSpacing: 0.0` consistent |
| Back button | Yes | Standard AppBar back arrow in SearchScreen |
| Brand voice | Yes | Minimal, consistent copy |
| Color usage | Yes | Warm amber for active streaks, blue for accents, muted grey for secondary |
| Typography hierarchy | Yes | H1→H2→H3 clearly differentiated; body/small well-separated |
| Empty states | Yes | Journal placeholder + search prompt + no-results message all covered |

---

### Step 4: Triage

---

## Critical — Must fix before launch

### C1: Arrow keys hijacked — cannot navigate cursor within multi-line text

**File:** `services/keyboard_service.dart:53-67`
**Persona:** Every user who writes more than one line

Arrow Up/Down unconditionally dispatch `NavigateUp/DownNotification`, moving focus to the adjacent record. This means users **cannot use arrow keys to move the cursor between lines** in a multi-line text record. This breaks a fundamental text editing expectation and makes multi-line records nearly unusable with keyboard navigation.

```dart
if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
  NavigateDownNotification(...).dispatch(context);  // always fires
  return KeyEventResult.handled;
}
```

**Fix:** Check the cursor position before intercepting:
- Arrow Up: only navigate to previous record when cursor is on the **first line** of the text field
- Arrow Down: only navigate to next record when cursor is on the **last line** of the text field
- Otherwise, let the default text field behavior handle cursor movement

This requires inspecting `textController.selection` and computing line positions relative to the `TextPainter` layout.

---

### C2: Habit name cannot be edited after creation

**File:** `widgets/records/habit_record_widget.dart:104-111`
**Persona:** Any user who makes a typo or wants to rename a habit

```dart
Expanded(
  child: Text(
    record.habitName.isNotEmpty ? record.habitName : record.content,
    style: theme.textTheme.bodyMedium?.copyWith(...),
  ),
),
```

The habit name is stored in `metadata['habit.name']` and rendered with a read-only `Text` widget. There is **no way to edit it** after creation. The only workaround — converting to text and back — loses all completion data.

**Fix:** Replace `Text` with a `RecordTextField` (or a simple `TextField`) that reads from `record.habitName` and writes back to `habit.name` metadata on change. The `onSave` callback already supports metadata updates via `record.copyWithMetadata(...)`.

---

### C3: Todo checkbox touch target is 20×20 — well below 44px minimum

**File:** `widgets/records/todo_record_widget.dart:47-57`, `theme/lifelog_theme.dart:196-198`
**Persona:** Mobile users, accessibility

The todo checkbox is wrapped in a `SizedBox(width: 20, height: 20)` and the theme sets `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap` plus `visualDensity: VisualDensity.compact`. This actively defeats Flutter's built-in touch target padding, producing a ~20×20px hit area.

This was addressed in Round 1 (enlarged to 48px) but then **reverted** in commit `1d3642e` ("restore compact checkbox size"). The visual density concern is valid, but the current target is less than half the recommended minimum.

**Comparison:** `HabitRecordWidget` correctly wraps its 20px icon in a 44×44 `SizedBox` with a centered `GestureDetector`. The same pattern should apply to the checkbox.

**Fix:** Keep the visual checkbox at 20px but wrap it in a 44×44 transparent touch area, matching the habit widget pattern:
```dart
SizedBox(
  width: GridConstants.minTouchTarget,  // 44
  height: GridConstants.minTouchTarget,
  child: Center(
    child: SizedBox(
      width: GridConstants.checkboxSize,  // 20
      height: GridConstants.checkboxSize,
      child: Checkbox(...),
    ),
  ),
)
```

---

## Major — Significant UX impact

### M1: Search results are not tappable — no navigation to source day

**File:** `widgets/search_screen.dart:241-249`
**Persona:** Any user searching for a past entry

Search results are display-only: `onSave: (_) {}`, `onDelete: (_) {}`, `readOnly: true`. Tapping a result does nothing. Users expect "search → tap result → jump to that day" as the standard pattern (Gmail, Notion, Apple Notes all do this).

**Fix:** Wrap each result group or individual result in a `GestureDetector` / `InkWell`. On tap, call `Navigator.pop(context, resultDate)` and have `JournalScreen` scroll to that date using `Scrollable.ensureVisible` or computing the scroll offset from the date.

---

### M2: TypePickerButton touch target is below minimum

**File:** `widgets/records/text_record_widget.dart:103-146`
**Persona:** Mobile users

The `+` button sits in a `SizedBox(width: 30, height: 28)` with a 14px icon. Both dimensions are below the 44px minimum. On mobile, this is difficult to tap accurately, and the small grey icon is also hard to discover.

**Fix:** Increase the SizedBox to at least 44×44 (it can extend into the padding area) and bump the icon to 18-20px. Consider using `onSurfaceVariant` color instead of `outline` for slightly better visibility.

---

### M3: WCAG AA contrast failure on secondary text

**File:** `theme/lifelog_theme.dart:27,41`
**Persona:** Users with low vision, users in bright sunlight

| Color pair | Ratio | WCAG AA (normal) | WCAG AA (large) |
|-----------|-------|----------|----------|
| `_inkLight` (#8A8A8A) on `_paperWhite` (#FAF8F5) | ~3.2:1 | Fail (needs 4.5:1) | Pass (needs 3:1) |
| `_darkInkLight` (#787572) on `_darkBackground` (#1A1A1A) | ~3.1:1 | Fail | Pass |

Affected elements: `bodySmall` (12px — habit streak, metadata), `labelSmall` (11px — "Saved" badge). These are all normal-size text, so 4.5:1 is required.

**Fix:** Darken `_inkLight` to at least `#737373` (~4.5:1 on #FAF8F5). Lighten `_darkInkLight` to at least `#9A9A9A` (~4.5:1 on #1A1A1A).

---

### M4: No record reordering capability

**Persona:** Users who want to reorganize their day's entries

Records have `orderPosition` (fractional, designed for insert-between), but there is no UI to reorder them. New records are always appended. The only way to change order is to delete and recreate.

For a journal app where narrative order matters (heading → context → todos → notes), this is a significant friction point.

**Fix:** Add long-press drag handles to `RecordSection` using `ReorderableListView` or a custom drag gesture. The fractional `orderPosition` already supports arbitrary reordering — it just needs a UI surface.

---

### M5: Type conversion can silently lose data

**File:** `widgets/records/text_record_widget.dart:62-97` (`TypePickerButton._convertTo`)
**Persona:** User who accidentally picks the wrong type

Converting between record types is immediate with no confirmation or undo:
- Text/heading → Habit: content moves to `habit.name`, original `content` is cleared
- Habit → Text: `habit.name` stays in metadata, `content` is empty (the text appears blank)
- Todo → Text: `todo.checked` state is lost

**Fix:** For conversions that lose data (especially habit ↔ anything), show a brief confirmation dialog or offer undo via SnackBar (matching the pattern already used for empty-record deletion).

---

### M6: No scroll-to-today affordance

**Persona:** User who has scrolled far into past entries

After scrolling through weeks of past entries, there is no quick way to return to today. The `_todayKey` scroll anchor exists but is only used for initial positioning. Users must scroll manually.

**Fix:** Add a conditional FAB or AppBar action that appears when the user has scrolled away from today. Tapping it scrolls to the today anchor. The search FAB at `miniEndTop` leaves room for a "today" button at `miniStartTop` or `miniEndFloat`.

---

### M7: Debounced save may not flush on app background/kill

**File:** `widgets/journal_screen.dart:129-146`
**Persona:** User who types and immediately switches apps

The 500ms debouncer means keystrokes within the last 500ms before the app is backgrounded or killed may not be saved. `dispose()` cancels debouncers but doesn't flush them.

**Fix:** In `_JournalScreenState.dispose()` (or via `WidgetsBindingObserver.didChangeAppLifecycleState`), flush all pending debouncers by calling their callbacks immediately before disposing. Alternatively, listen for `AppLifecycleState.inactive` or `paused` and force-flush.

---

## Minor / Polish

### P1: Search date headers use hardcoded padding, breaking tablet/desktop alignment

**File:** `widgets/search_screen.dart:230-231`

```dart
padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
```

This doesn't use `GridConstants.calculateContentLeftPadding()`, so on tablet (40px) and desktop (64px), the date headers are misaligned with the search field and record content above/below them.

**Fix:** Use the same responsive padding calculation as the search field.

---

### P2: Empty-day minimum height (96px) creates large blank gaps

**File:** `widgets/day_section.dart:93-95`

```dart
constraints: const BoxConstraints(minHeight: GridConstants.spacing * 4),  // 96px
```

Empty future days take up 96px each, creating a lot of blank space when scrolling into the future. Since the journal is infinite in both directions, this compounds quickly.

**Fix:** Reduce to `spacing * 2` (48px) for a tighter feel, or make the minimum conditional on whether the day is in the past (larger, since it may have had content) vs. future (smaller).

---

### P3: TypePickerButton menu items use fragile Unicode spacing

**File:** `widgets/records/text_record_widget.dart:117-137`

```dart
const PopupMenuItem(value: RecordType.text, child: Text('T   Text')),
const PopupMenuItem(value: RecordType.todo, child: Text('☐   Todo')),
```

The alignment depends on the character width of `T`, `☐`, `•`, `○` in the current font, which varies. The multi-space gap is also fragile.

**Fix:** Use a `Row` with a fixed-width `SizedBox(width: 24)` for the icon and a `Text` for the label, or use `ListTile(leading: ...)` for proper Material alignment.

---

### P4: FTS5 special characters could cause search query errors

**File:** `database/record_repository.dart` (search method)

FTS5 interprets `*`, `"`, `NEAR`, `OR`, `AND`, `NOT` as query syntax. A user searching for `"important"` (with quotes) or `meeting * notes` could trigger unexpected behavior or errors.

**Fix:** Escape or quote the user's query before passing to FTS5, e.g., wrap the entire query in double quotes: `'"$escapedQuery"'`.

---

### P5: Dark theme "Saved" badge has low visibility

**File:** `widgets/journal_screen.dart:279-291`

The badge uses `surfaceContainerHighest.withValues(alpha: 0.9)`. In dark mode, this is a semi-transparent dark surface on a dark background — the badge may be difficult to notice.

**Fix:** Add a subtle 1px border using `outlineVariant`, or use a slightly lighter surface color in dark mode.

---

### P6: `_recordsByDate` cache grows unboundedly

**File:** `widgets/journal_screen.dart:30`

Every day that is scrolled past is cached in `_recordsByDate` forever. For long sessions with extensive scrolling, this accumulates memory.

**Fix:** Implement an LRU eviction strategy (e.g., keep the most recent 30 days cached, evict older entries). The `FutureBuilder` in `DaySection` will re-fetch when the user scrolls back.

---

## Architecture Notes (non-actionable)

1. **No state management library** — local StatefulWidget state. Clean at this scale, but adding sync, undo history, or collaborative features would benefit from a reactive state solution.
2. **Event sourcing table is write-only** — `event_log` records all mutations but is never read. Good forward planning for sync but adds write overhead with no current benefit.
3. **FutureBuilder re-creates futures on rebuild** — `DaySection` receives `recordsFuture` which is computed in `_getRecordsForDate`. The cache prevents duplicate DB calls, but the `FutureBuilder` still re-subscribes on each parent rebuild.

---

## Summary

| Severity | Count | Key Themes |
|----------|-------|------------|
| **Critical** | 3 | Arrow key hijacking, frozen habit names, todo touch targets |
| **Major** | 7 | Search navigation, contrast, reordering, data loss on conversion, save flush |
| **Minor** | 6 | Padding consistency, cache growth, FTS5 escaping |

**Recommended priority order:**
1. **C1** (arrow keys) — breaks fundamental text editing
2. **C2** (habit name) — creates permanent data errors
3. **C3** (todo touch target) — accessibility compliance
4. **M3** (contrast) — accessibility compliance
5. **M1** (search navigation) — completes the search workflow
6. **M7** (save flush) — prevents data loss
7. Remaining majors and minors by effort/impact
