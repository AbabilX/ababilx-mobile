import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat-people/user_qr_payload.dart';
import 'package:ababilx/features/messages/group-link/group_link_payload.dart';
import 'package:ababilx/features/share_intake/data/shared_payload.dart';

void main() {
  test('round-trips a slug through the shared link', () {
    final link = buildGroupLink('Book-Club');
    expect(link, 'https://www.ababilx.com/g/book-club');
    expect(slugFromGroupLink(link), 'book-club');
  });

  test('reads the scheme form the site button fires', () {
    expect(slugFromGroupLink('ababilx://group?g=book-club'), 'book-club');
    expect(slugFromGroupLink('https://ababilx.com/g/dhaka.devs'), 'dhaka.devs');
  });

  test('a group link is never a person, and the reverse', () {
    expect(usernameFromQrPayload('https://www.ababilx.com/g/murad'), isNull);
    expect(usernameFromQrPayload('ababilx://group?g=murad'), isNull);
    expect(slugFromGroupLink('https://www.ababilx.com/u/murad'), isNull);
    expect(slugFromGroupLink('ababilx://user?u=murad'), isNull);
  });

  test('refuses foreign hosts and malformed slugs', () {
    expect(slugFromGroupLink('https://evil.com/g/book-club'), isNull);
    expect(slugFromGroupLink('http://www.ababilx.com/g/book-club'), isNull);
    expect(slugFromGroupLink('https://www.ababilx.com/g/book-club/x'), isNull);
    expect(slugFromGroupLink('https://www.ababilx.com/g/ab'), isNull);
    expect(slugFromGroupLink('ababilx://group?g=../x'), isNull);
    expect(slugFromGroupLink('book-club'), isNull);
  });

  test('the intake payload carries a slug, checked again', () {
    expect(
      SharedPayload.openGroupSlug('{"open_group":"book-club"}'),
      'book-club',
    );
    expect(SharedPayload.openGroupSlug('{"open_group":"x/details"}'), isNull);
    expect(SharedPayload.openGroupSlug('{"open_user":"murad"}'), isNull);
    expect(SharedPayload.openUserHandle('{"open_group":"book-club"}'), isNull);
    expect(SharedPayload.tryParse('{"open_group":"book-club"}'), isNull);
  });
}
