import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/data/models/chat_models.dart';

/// Note to Self is an ordinary personal DM whose two participants are the same
/// account, so `isDm` is true and `peerUserId` is the viewer's own id. Every
/// surface that needs a second person has to ask `hasDmPeer` instead — a bare
/// `isDm` check is exactly the mistake that would offer somebody a call to
/// themselves, a nickname for themselves, or a Block button aimed at their own
/// account.
ChatConversation _conv({
  required bool isSelf,
  String requestState = 'none',
  String? peerUserId = 'u1',
}) => ChatConversation(
  id: 'c1',
  teamId: '',
  scope: 'personal',
  type: 'dm',
  createdAt: '2026-09-09T00:00:00Z',
  peerUserId: peerUserId,
  peerUserName: 'Murad',
  requestState: requestState,
  isSelf: isSelf,
);

void main() {
  test('a note to self is titled by the feature, not by its peer', () {
    expect(_conv(isSelf: true).displayTitle('u1'), 'Note to Self');
    expect(_conv(isSelf: false).displayTitle('u2'), 'Murad');
  });

  test('a note to self has no peer, an ordinary DM does', () {
    expect(_conv(isSelf: true).hasDmPeer, isFalse);
    expect(_conv(isSelf: false).hasDmPeer, isTrue);
    // The guard is about the second person, not about a missing field.
    expect(_conv(isSelf: false, peerUserId: null).hasDmPeer, isFalse);
  });

  test('a note to self can never show a message request', () {
    // A stale row from an older server could still carry "incoming"; the bar
    // replaces the composer, so this must not depend on the server blanking it.
    expect(
      _conv(isSelf: true, requestState: 'incoming').isIncomingRequest,
      isFalse,
    );
    expect(
      _conv(isSelf: false, requestState: 'incoming').isIncomingRequest,
      isTrue,
    );
  });

  test('is_self survives the JSON round trip and defaults to false', () {
    final parsed = ChatConversation.fromJson({
      'id': 'c1',
      'type': 'dm',
      'scope': 'personal',
      'created_at': '2026-09-09T00:00:00Z',
      'is_self': true,
    });
    expect(parsed.isSelf, isTrue);
    expect(parsed.displayTitle('u1'), 'Note to Self');

    final legacy = ChatConversation.fromJson({
      'id': 'c2',
      'type': 'dm',
      'scope': 'personal',
      'created_at': '2026-09-09T00:00:00Z',
    });
    expect(legacy.isSelf, isFalse);
  });

  test('copyWith keeps it: a patched row must not turn back into a DM', () {
    expect(_conv(isSelf: true).copyWith(unreadCount: 3).isSelf, isTrue);
  });
}
