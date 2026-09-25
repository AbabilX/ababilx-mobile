import 'package:ababilx/features/notifications/full_screen_intent_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

/// "After an update or a fresh install I have to unlock the phone to take a
/// call." The Settings page for full-screen notifications is an ordinary
/// Activity: opened on a locked phone it asks for the PIN, opened by a cold
/// start that an Accept caused it covers the call. It was opened on every
/// cold start.
void main() {
  const build = 31;

  test('asks once per build, on an unlocked phone with no call', () {
    expect(
      shouldAskFullScreenIntent(
        locked: false,
        callLive: false,
        foreground: true,
        askedBuild: null,
        build: build,
      ),
      isTrue,
    );
    expect(
      shouldAskFullScreenIntent(
        locked: false,
        callLive: false,
        foreground: true,
        askedBuild: build,
        build: build,
      ),
      isFalse,
    );
    expect(
      shouldAskFullScreenIntent(
        locked: false,
        callLive: false,
        foreground: true,
        askedBuild: build - 1,
        build: build,
      ),
      isTrue,
    );
  });

  test('never on a locked phone — Settings would demand the PIN', () {
    expect(
      shouldAskFullScreenIntent(
        locked: true,
        callLive: false,
        foreground: true,
        askedBuild: null,
        build: build,
      ),
      isFalse,
    );
  });

  test('never while a call rings or runs — Settings would cover it', () {
    expect(
      shouldAskFullScreenIntent(
        locked: false,
        callLive: true,
        foreground: true,
        askedBuild: null,
        build: build,
      ),
      isFalse,
    );
  });

  test('never from the background', () {
    expect(
      shouldAskFullScreenIntent(
        locked: false,
        callLive: false,
        foreground: false,
        askedBuild: null,
        build: build,
      ),
      isFalse,
    );
  });
}
