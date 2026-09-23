import 'package:ababilx/features/messages/wallpaper/chat_wallpaper.dart';
import 'package:ababilx/features/messages/wallpaper/chat_wallpaper_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = ChatWallpaperStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reset every chat keeps the global default it resets them to', () async {
    await store.writeGlobal(ChatWallpaper.preset(chatWallpaperDewdropId));
    await store.writeForChat('c1', ChatWallpaper.photo('/a.jpg'));
    await store.clearAllOverrides();
    expect((await store.readGlobal()).presetId, chatWallpaperDewdropId);
    expect(await store.readForChat('c1'), isNull);
  });

  test('a photo is in use while any stored wallpaper paints it', () async {
    await store.writeForChat('c1', ChatWallpaper.photo('/a.jpg'));
    expect(await store.photoInUse('/a.jpg'), isTrue);
    expect(await store.photoInUse('/b.jpg'), isFalse);
    await store.writeForChat('c1', null);
    expect(await store.photoInUse('/a.jpg'), isFalse);
  });
}
