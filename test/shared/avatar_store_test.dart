import 'package:ababilx/shared/avatar-store/avatar_index.dart';
import 'package:ababilx/shared/avatar-store/avatar_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google pictures are asked for at the stored size', () {
    expect(
      AvatarStore.normalize('https://lh3.googleusercontent.com/a/x=s96-c'),
      'https://lh3.googleusercontent.com/a/x=s288-c',
    );
    expect(AvatarStore.normalize('  '), isNull);
    expect(AvatarStore.normalize(null), isNull);
  });

  test('before init nothing is looked up and nothing is fetched', () async {
    expect(AvatarStore.instance.fileFor('https://cdn.example/a.jpg'), isNull);
    expect(
      await AvatarStore.instance.ensure('https://cdn.example/a.jpg'),
      isNull,
    );
  });

  test('the trim drops bare-URL keys before owners, oldest first', () {
    final entries = <String, AvatarEntry>{
      for (var i = 0; i < 3000; i++)
        'user:$i': AvatarEntry(url: 'u$i', file: 'f$i', at: i),
      'https://old': const AvatarEntry(url: 'o', file: 'fo', at: 1),
      'https://new': const AvatarEntry(url: 'n', file: 'fn', at: 9999),
    };
    expect(AvatarIndex.overflow(entries), ['https://old', 'https://new']);
  });
}
