import 'dart:convert';

import 'package:ababilx/features/calls/group/signals/call_signals.dart';
import 'package:flutter_test/flutter_test.dart';

// The same wire bytes are pinned in the desktop/web call-signals.test.mjs. If
// one side changes, the other has to change with it or a hand raised on a
// phone is invisible in a browser, with no error anywhere.
const raisedHand = '{"t":"hand","raised":true}';
const reaction = '{"t":"reaction","emoji":"👍"}';

void main() {
  group('call signals', () {
    test('the topic is fixed', () {
      expect(callSignalTopic, 'ababilx-call');
    });

    test('encodes the pinned wire format', () {
      expect(utf8.decode(encodeCallSignal(const HandSignal(true))), raisedHand);
      expect(
        utf8.decode(encodeCallSignal(const ReactionSignal('👍'))),
        reaction,
      );
    });

    test('decodes what the other platform sends', () {
      final hand = decodeCallSignal(utf8.encode(raisedHand));
      expect(hand, isA<HandSignal>());
      expect((hand as HandSignal).raised, isTrue);

      final emoji = decodeCallSignal(utf8.encode(reaction));
      expect(emoji, isA<ReactionSignal>());
      expect((emoji as ReactionSignal).emoji, '👍');
    });

    test('rejects anything malformed rather than throwing', () {
      expect(decodeCallSignal(utf8.encode('not json')), isNull);
      expect(decodeCallSignal(utf8.encode('{"t":"hand"}')), isNull);
      expect(decodeCallSignal(utf8.encode('{"t":"reaction"}')), isNull);
      expect(decodeCallSignal(utf8.encode('{"t":"nope"}')), isNull);
    });

    test('hands come out oldest first — that is the queue', () {
      final queue = handQueue({
        'carol': DateTime(2026, 1, 1, 0, 0, 3),
        'alice': DateTime(2026, 1, 1, 0, 0, 1),
        'bob': DateTime(2026, 1, 1, 0, 0, 2),
      });
      expect(queue, ['alice', 'bob', 'carol']);
    });

    test('the reaction set matches the other platforms', () {
      expect(callReactions, ['❤️', '👍', '👋', '😂', '😮', '🎉', '😢', '🙏']);
    });
  });
}
