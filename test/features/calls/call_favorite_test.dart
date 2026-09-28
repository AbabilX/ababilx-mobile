import 'package:ababilx/features/calls/favorites/call_favorite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a favourite survives a round trip through storage', () {
    const f = CallFavorite(
      conversationId: 'c1',
      peerUserId: 'u1',
      name: 'Ada',
      avatarUrl: 'https://cdn/a.jpg',
    );
    final back = CallFavorite.fromJson(f.toJson())!;
    expect(back.conversationId, 'c1');
    expect(back.peerUserId, 'u1');
    expect(back.name, 'Ada');
    expect(back.avatarUrl, 'https://cdn/a.jpg');
  });

  test('an unreadable entry is dropped, not a crash', () {
    expect(CallFavorite.fromJson(null), isNull);
    expect(CallFavorite.fromJson({'c': ''}), isNull);
    expect(CallFavorite.fromJson('junk'), isNull);
  });
}
