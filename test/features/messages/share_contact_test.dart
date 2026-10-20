import 'package:ababilx/features/messages/chat-details/share_contact.dart';
import 'package:ababilx/features/messages/chat-people/user_qr_payload.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation_json.dart';
import 'package:ababilx/features/share_intake/data/shared_payload.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _dm(Map<String, dynamic> extra) => ChatConversation.fromJson({
  'id': 'c1',
  'type': 'dm',
  'peer_user_id': 'u2',
  'peer_user_name': 'Mahmudul',
  ...extra,
});

void main() {
  test('link carries username, else email, else phone', () {
    expect(
      sharedContactLink(
        _dm({'peer_share_handle': 'murad', 'peer_share_email': 'm@x.com'}),
      ),
      'https://www.ababilx.com/u/murad',
    );
    expect(
      sharedContactLink(
        _dm({
          'peer_share_email': 'M@X.com',
          'peer_share_phone': '+8801712345678',
        }),
      ),
      'https://www.ababilx.com/u/m%40x.com',
    );
    expect(
      sharedContactLink(_dm({'peer_share_phone': '+8801712345678'})),
      'https://www.ababilx.com/u/%2B8801712345678',
    );
    expect(sharedContactLink(_dm({})), '');
    expect(
      sharedContactBody('Murad', 'https://www.ababilx.com/u/murad'),
      'Murad\nhttps://www.ababilx.com/u/murad',
    );
  });

  test('each link reads back to what it carries', () {
    for (final (link, ref) in [
      ('https://www.ababilx.com/u/murad', 'murad'),
      ('https://www.ababilx.com/u/m%40x.com', 'm@x.com'),
      ('https://www.ababilx.com/u/%2B8801712345678', '+8801712345678'),
    ]) {
      expect(usernameFromQrPayload(link), ref, reason: link);
    }
    expect(
      usernameFromQrPayload('https://www.ababilx.com/u/not an email'),
      isNull,
    );
  });

  test('app link intake keeps an email or a phone for open_user', () {
    expect(SharedPayload.openUserHandle('{"open_user":"m@x.com"}'), 'm@x.com');
    expect(
      SharedPayload.openUserHandle('{"open_user":"+8801712345678"}'),
      '+8801712345678',
    );
    expect(SharedPayload.openUserHandle('{"open_user":"Murad"}'), 'murad');
    expect(SharedPayload.openGroupSlug('{"open_group":"m@x.com"}'), isNull);
  });

  test('share fields survive the sidebar cache', () {
    final c = _dm({'peer_share_email': 'm@x.com', 'peer_share_phone': '+1'});
    final back = ChatConversation.fromJson(c.toJson());
    expect(back.peerShareEmail, 'm@x.com');
    expect(back.peerSharePhone, '+1');
    expect(back.canShareContact, isTrue);
  });
}
