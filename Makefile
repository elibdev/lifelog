# Lifelog development helpers
#
# goldens: Regenerate component screenshot PNGs committed to reference/test/goldens/.
# Run this after any visual change to a widget in the reference implementation.
# The Docker target ensures pixel-identical output across macOS, Linux, and Windows
# by pinning the renderer to a single Linux environment.

FLUTTER ?= /opt/flutter/bin/flutter

# Regenerate goldens locally (requires Flutter on PATH or FLUTTER env override).
goldens:
	cd reference && $(FLUTTER) test --update-goldens test/screenshots/
	@echo "Goldens written to reference/test/goldens/. Inspect and commit."

# Verify goldens match committed PNGs (used in CI).
test-goldens:
	cd reference && $(FLUTTER) test test/screenshots/

# Regenerate goldens via Docker for cross-platform consistency.
# Requires Docker to be running. Output is written to reference/test/goldens/.
goldens-docker:
	docker run --rm \
	  -v $(PWD)/reference:/app \
	  -w /app \
	  ghcr.io/cirruslabs/flutter:stable \
	  flutter test --update-goldens test/screenshots/
	@echo "Goldens written to reference/test/goldens/ via Docker."

.PHONY: goldens test-goldens goldens-docker
