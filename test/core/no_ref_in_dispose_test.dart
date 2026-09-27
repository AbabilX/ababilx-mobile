import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `ref` inside a ConsumerState's `dispose()` throws — the element is already
/// unmounted when Flutter calls it — and the throw also skips riverpod closing
/// that widget's `watch` subscriptions. Every later change to a watched
/// provider then marks a dead element dirty:
/// `'_lifecycleState != _ElementLifecycle.defunct': is not true`.
/// ConversationScreen did this, and leaving a chat never cleared the active
/// conversation or marked it read. Capture `ProviderScope.containerOf(context,
/// listen: false)` in initState and read through that instead — and WRITE
/// through it only after the frame (`scheduleMicrotask`): flutter_riverpod
/// also throws, in debug, on any provider change made inside dispose.
void main() {
  test('no ConsumerState reads ref in dispose()', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('ConsumerState<')) continue;
      for (final match in RegExp(r'void dispose\(\)\s*\{').allMatches(source)) {
        var depth = 1;
        var i = match.end;
        while (depth > 0 && i < source.length) {
          if (source[i] == '{') depth++;
          if (source[i] == '}') depth--;
          i++;
        }
        if (RegExp(r'\bref\.').hasMatch(source.substring(match.end, i))) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${entity.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
