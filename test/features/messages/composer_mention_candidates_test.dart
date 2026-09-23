import 'package:ababilx/features/messages/chat-timeline/composer_mention_candidates.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_mention_picker.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _conv(String type, {String? peer, String? peerName}) =>
    ChatConversation(
      id: 'c1',
      teamId: '',
      scope: 'personal',
      type: type,
      name: 'Room',
      createdAt: '2026-09-01T10:00:00Z',
      peerUserId: peer,
      peerUserName: peerName,
    );

const _connections = [
  ChatUserSummary(userId: 'b', name: 'Bina'),
  ChatUserSummary(userId: 'c', name: 'Chand'),
  ChatUserSummary(userId: 'd', name: 'Dipu'),
];

const _members = [
  MentionCandidate(userId: 'me', displayName: 'Me'),
  MentionCandidate(userId: 'b', displayName: 'Bina'),
];

List<MentionCandidate> _build(
  ChatConversation conv, {
  bool loaded = true,
  String query = '',
}) => buildMentionCandidates(
  conversation: conv,
  currentUserId: 'me',
  members: _members,
  membersLoaded: loaded,
  connections: _connections,
  query: query,
);

void main() {
  test('a DM offers only the other person', () {
    final out = _build(_conv('dm', peer: 'x', peerName: 'Xavier'));
    expect(out.map((c) => c.userId), ['x']);
  });

  test('a group lists members first, then connections as outsiders', () {
    final out = _build(_conv('group'));
    expect(out.first.isAll, isTrue);
    expect(out.skip(1).map((c) => c.userId), ['b', 'c', 'd']);
    expect(out.skip(1).map((c) => c.isInChannel), [true, false, false]);
  });

  test('outsiders wait for the member list', () {
    expect(_build(_conv('group'), loaded: false).map((c) => c.displayName), [
      'all',
      'Bina',
    ]);
  });

  test('the query filters both sections', () {
    expect(_build(_conv('group'), query: 'ch').map((c) => c.userId), ['c']);
  });

  test('@all only shows while the query fits it', () {
    final out = _build(_conv('group'), query: 'al');
    expect(out.map((c) => c.isAll), [true]);
  });
}
