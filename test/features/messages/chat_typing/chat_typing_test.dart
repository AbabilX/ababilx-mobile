import 'package:ababilx/features/messages/chat-typing/chat_typing_provider.dart';
import 'package:ababilx/features/messages/chat-typing/typing_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('typingLabel', () {
    test('nobody typing says nothing', () {
      expect(typingLabel(const [], isGroup: true), '');
    });
    test('a DM never names the peer', () {
      expect(typingLabel(const ['Alice'], isGroup: false), 'typing…');
    });
    test('a group names who — same wording as web', () {
      expect(typingLabel(const ['Alice'], isGroup: true), 'Alice is typing…');
      expect(
        typingLabel(const ['Alice', 'Bob'], isGroup: true),
        'Alice and Bob are typing…',
      );
      expect(
        typingLabel(const ['A', 'B', 'C'], isGroup: true),
        'A, B and C are typing…',
      );
      expect(
        typingLabel(const ['A', 'B', 'C', 'D', 'E'], isGroup: true),
        'A, B and 3 others are typing…',
      );
      expect(typingLabel(const ['  '], isGroup: true), 'Someone is typing…');
    });
  });

  test('typists are listed oldest first', () {
    final now = DateTime(2026, 9, 16, 10);
    final names = typingNamesOf({
      'b': Typist('Bob', now.add(const Duration(seconds: 1))),
      'a': Typist('Alice', now),
    });
    expect(names, ['Alice', 'Bob']);
    expect(typingNamesOf(null), isEmpty);
  });
}
