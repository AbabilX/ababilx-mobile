import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ababilx/features/calls/decline-message/decline_replies.dart';

/// The keys are read by android/patches/callkit/CallkitDeclineReplies.kt.
/// Renaming one side alone hides the Message button, or loses the reply.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'native extra carries the presets and labels under fixed keys',
    () async {
      final extra = await DeclineReplies.nativeExtra();
      expect(extra.keys, {
        'decline_replies',
        'decline_replies_button',
        'decline_replies_title',
        'decline_replies_cancel',
      });
      final presets = extra['decline_replies']!.split('\n');
      expect(presets, hasLength(DeclineReplies.presetKeys.length));
      expect(
        presets.every((p) => p.trim().isNotEmpty && !p.contains('\n')),
        isTrue,
      );
    },
  );

  test('Bangla presets follow the remembered language', () async {
    await DeclineReplies.rememberLanguage('bn');
    final extra = await DeclineReplies.nativeExtra();
    expect(extra['decline_replies_button'], 'মেসেজ');
    await DeclineReplies.rememberLanguage('en');
  });

  test('the chosen reply is read off the decline extra, trimmed', () {
    expect(
      DeclineReplies.messageOf({'decline_message': '  On my way  '}),
      'On my way',
    );
    expect(DeclineReplies.messageOf({'decline_message': '   '}), isNull);
    expect(DeclineReplies.messageOf({'type': 'voice_call'}), isNull);
    expect(DeclineReplies.messageOf(null), isNull);
  });
}
