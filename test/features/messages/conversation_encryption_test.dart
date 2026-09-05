import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/data/models/chat_conversation.dart';

ChatConversation conversation(String scope, String type) =>
    ChatConversation.fromJson({
      'id': 'c1',
      'scope': scope,
      'type': type,
      'name': 'x',
    });

// The mirror of e2eeEligible on the server. Drift shows up as the server
// refusing plaintext this client happily sends (409) or refusing ciphertext it
// sends anyway (400) — either way a conversation nobody can post in.
void main() {
  test('DMs are encrypted in either scope', () {
    expect(conversation('personal', 'dm').isEncrypted, isTrue);
    expect(conversation('workspace', 'dm').isEncrypted, isTrue);
  });

  test('personal groups are encrypted', () {
    expect(conversation('personal', 'group').isEncrypted, isTrue);
  });

  test('workspace channels are never encrypted', () {
    // Server-side search cannot read ciphertext, and a channel exists to be
    // searched. This is a decision, not a gap.
    expect(conversation('workspace', 'channel').isEncrypted, isFalse);
    expect(conversation('workspace', 'group').isEncrypted, isFalse);
  });
}
