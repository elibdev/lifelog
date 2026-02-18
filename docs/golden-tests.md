# Flutter Golden Tests — Component Screenshots

Golden tests render widgets through Flutter's headless software rasterizer and
save the output as PNG files. The PNGs are committed to the repo so you can:

- Browse the component library visually on GitHub
- Catch unintended visual regressions in CI (any pixel change fails the test)

---

## File layout

```
reference/
├── test/
│   ├── goldens/                      ← committed PNG output (18 files)
│   │   ├── text_record_default.png
│   │   ├── heading_h1.png
│   │   ├── heading_h2.png
│   │   ├── heading_h3.png
│   │   ├── todo_unchecked.png
│   │   ├── todo_checked.png
│   │   ├── bullet_indent0.png
│   │   ├── bullet_indent1.png
│   │   ├── bullet_indent2.png
│   │   ├── habit_not_completed.png
│   │   ├── habit_completed_today.png
│   │   ├── habit_long_streak.png
│   │   ├── record_text_field_default.png
│   │   ├── record_text_field_bold.png
│   │   ├── record_section_mixed.png
│   │   ├── day_section_mixed.png
│   │   ├── dotted_grid_light.png
│   │   └── dotted_grid_dark.png
│   └── screenshots/                  ← test files
│       ├── record_widgets_test.dart
│       ├── layout_widgets_test.dart
│       └── decorations_test.dart
└── Makefile
```

---

## Commands

| Command | Effect |
|---|---|
| `make goldens` | Regenerate all PNGs locally |
| `make test-goldens` | Assert no visual regressions (CI mode) |
| `make goldens-docker` | Regenerate via Docker (cross-platform safe) |

Or run Flutter directly from `reference/`:

```bash
# Regenerate
flutter test --update-goldens test/screenshots/

# Verify (no --update-goldens)
flutter test test/screenshots/
```

---

## Workflow for intentional visual changes

When you change a widget's appearance:

1. Run `make goldens` to regenerate the PNGs.
2. Inspect the changed files with `git diff` (binary diffs) or open them in a viewer.
3. Commit the updated PNGs alongside the code change.

---

## Why goldens look the way they do

Flutter's test environment does not load system fonts; text renders using Flutter's
internal test font which draws solid-coloured rectangles in place of glyphs. This is
intentional — it makes comparisons pixel-stable across every platform, so CI on
Linux never fails because macOS rendered the 'g' in "groceries" one pixel differently.

The widget structure (colours, sizes, layout, icons) is faithfully reproduced even
without readable text.

---

## Cross-platform consistency

If you generate goldens on macOS and CI runs on Linux, comparisons will fail due to
sub-pixel font differences. Two mitigations:

1. **Always regenerate on Linux** — use `make goldens-docker` which runs the
   generator inside `ghcr.io/cirruslabs/flutter:stable`.
2. **Always regenerate in CI** — add a CI step that runs `--update-goldens` and
   commits the result, so the committed PNGs always match the CI renderer.

In this repo the goldens are generated on Linux (same environment as CI), so
`make goldens` without Docker is sufficient for solo development.

---

## Adding tests for new components

1. Add a `testWidgets` call to the appropriate test file in `test/screenshots/`.
2. Use `matchesGoldenFile('../goldens/your_component_name.png')`.
3. Run `make goldens` to generate the new PNG.
4. Commit both the test file and the PNG.

The `_wrap` helper and `_record` fixture factory in each test file follow the same
conventions as the Widgetbook use cases — fixed 500 px content width, light theme,
stable non-today dates.
