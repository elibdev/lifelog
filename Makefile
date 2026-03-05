# Lifelog development helpers
#
# goldens: Regenerate component screenshot PNGs for both reference/ and app/.
# Run this after any visual change to a widget.
# The Docker target ensures pixel-identical output across macOS, Linux, and Windows
# by pinning the renderer to a single Linux environment.

FLUTTER ?= /opt/flutter/bin/flutter

# Regenerate goldens locally (requires Flutter on PATH or FLUTTER env override).
goldens:
	cd reference && $(FLUTTER) test --update-goldens test/screenshots/
	cd app && $(FLUTTER) test --update-goldens test/screenshots/
	@echo "Goldens written to {reference,app}/test/goldens/. Inspect and commit."

# Regenerate only app goldens.
goldens-app:
	cd app && $(FLUTTER) test --update-goldens test/screenshots/
	@echo "Goldens written to app/test/goldens/. Inspect and commit."

# Regenerate only reference goldens.
goldens-ref:
	cd reference && $(FLUTTER) test --update-goldens test/screenshots/
	@echo "Goldens written to reference/test/goldens/. Inspect and commit."

# Verify goldens match committed PNGs (used in CI).
test-goldens:
	cd reference && $(FLUTTER) test test/screenshots/
	cd app && $(FLUTTER) test test/screenshots/

# Regenerate goldens via Docker for cross-platform consistency.
goldens-docker:
	docker run --rm \
	  -v $(PWD)/reference:/app \
	  -w /app \
	  ghcr.io/cirruslabs/flutter:stable \
	  flutter test --update-goldens test/screenshots/
	docker run --rm \
	  -v $(PWD)/app:/app \
	  -w /app \
	  ghcr.io/cirruslabs/flutter:stable \
	  flutter test --update-goldens test/screenshots/
	@echo "Goldens written to {reference,app}/test/goldens/ via Docker."

.PHONY: goldens goldens-app goldens-ref test-goldens goldens-docker
