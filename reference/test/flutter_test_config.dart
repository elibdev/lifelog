import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// flutter_test_config.dart is automatically executed by `flutter test` before
// any test in this directory tree. It is the standard hook for global test setup.
// See: https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadMaterialFonts();
  await testMain();
}

// Load Roboto and MaterialIcons from the Flutter SDK's bundled font cache.
//
// By default, Flutter tests use the "Ahem" font which renders every character
// as a solid rectangle — stable across platforms but unreadable. Loading the
// real fonts makes golden screenshots useful for human review on GitHub.
//
// Roboto and MaterialIcons are already on disk (downloaded by `flutter pub get`)
// so this adds no network dependency to the test run.
//
// The FLUTTER_ROOT env var is set by `flutter test`; the fallback covers cases
// where tests are run via `dart test` or in Docker without it set.
Future<void> _loadMaterialFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final fontDir = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<ByteData> load(String name) async {
    final bytes = await File('$fontDir/$name').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  // Regular and weight variants used by Material 3 text styles.
  final roboto = FontLoader('Roboto')
    ..addFont(load('Roboto-Regular.ttf'))
    ..addFont(load('Roboto-Bold.ttf'))
    ..addFont(load('Roboto-Medium.ttf'))
    ..addFont(load('Roboto-Italic.ttf'))
    ..addFont(load('Roboto-BoldItalic.ttf'))
    ..addFont(load('Roboto-MediumItalic.ttf'))
    ..addFont(load('Roboto-Light.ttf'))
    ..addFont(load('Roboto-Thin.ttf'));
  await roboto.load();

  // Icons font — without this, Icons.check_circle etc. render as rectangles.
  final icons = FontLoader('MaterialIcons')
    ..addFont(load('MaterialIcons-Regular.otf'));
  await icons.load();
}
