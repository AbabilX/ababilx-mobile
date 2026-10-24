import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/nickname/contact_nickname.dart';
import 'package:ababilx/features/messages/nickname/nickname_title.dart';
import 'package:ababilx/shared/text/display_name.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _dm({String? peerName, String peerId = 'peer'}) =>
    ChatConversation(
      id: 'c1',
      teamId: '',
      scope: 'personal',
      type: 'dm',
      createdAt: '2026-09-03T00:00:00Z',
      peerUserId: peerId,
      peerUserName: peerName,
    );

const _group = ChatConversation(
  id: 'c2',
  teamId: '',
  scope: 'personal',
  type: 'group',
  createdAt: '2026-09-03T00:00:00Z',
  name: 'Full Team',
);

void main() {
  group('ContactNicknames', () {
    test('a nickname wins over the name the account chose', () {
      const nicknames = ContactNicknames({'peer': 'Junayed'});
      expect(
        nicknames.resolve(userId: 'peer', name: 'Someone Else'),
        'Junayed',
      );
    });

    test('without one, the account name shows, sanitised', () {
      const nicknames = ContactNicknames();
      expect(nicknames.resolve(userId: 'peer', name: 'Murad'), 'Murad');
      expect(
        nicknames.resolve(userId: 'peer', name: 'Murad\nHossain'),
        'Murad Hossain',
      );
    });

    // The whole point of the feature: an unreadable name becomes readable.
    test('renames a peer whose own name renders as nothing', () {
      const blank = 'ㅤㅤ'; // U+3164 Hangul fillers
      const none = ContactNicknames();
      expect(none.resolve(userId: 'peer', name: blank), 'AbabilX user');
      const named = ContactNicknames({'peer': 'Junayed'});
      expect(named.resolve(userId: 'peer', name: blank), 'Junayed');
    });

    test('a nickname is sanitised like any other name', () {
      const nicknames = ContactNicknames({'peer': 'Boss\u202Eman'});
      expect(nicknames.resolve(userId: 'peer', name: 'x'), 'Bossman');
    });

    test('setting an empty nickname clears it', () {
      const nicknames = ContactNicknames({'peer': 'Junayed'});
      expect(nicknames.withNickname('peer', '  ').forUser('peer'), isNull);
      expect(nicknames.withNickname('peer', null).forUser('peer'), isNull);
      expect(nicknames.withNickname('peer', ' Ajoy ').forUser('peer'), 'Ajoy');
    });

    test('an unknown or missing user id has no nickname', () {
      const nicknames = ContactNicknames({'peer': 'Junayed'});
      expect(nicknames.forUser('other'), isNull);
      expect(nicknames.forUser(null), isNull);
      expect(nicknames.forUser(''), isNull);
    });
  });

  group('titleFor', () {
    test('renames a DM but never a group', () {
      const nicknames = ContactNicknames({'peer': 'Junayed'});
      expect(nicknames.titleFor(_dm(peerName: 'Murad'), 'me'), 'Junayed');
      expect(nicknames.titleFor(_group, 'me'), 'Full Team');
    });

    test('a DM with no name and no nickname reads as a nameless person', () {
      // Server folds @username into an empty name (0185); with neither,
      // every surface says "AbabilX user", never a blank or "Direct message".
      const nicknames = ContactNicknames();
      expect(nicknames.titleFor(_dm(), 'me'), namelessUserLabel);
    });
  });
}
