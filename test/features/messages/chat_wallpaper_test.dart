import 'package:ababilx/features/messages/wallpaper/chat_wallpaper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a wallpaper survives a round trip', () {
    const original = ChatWallpaper(
      kind: ChatWallpaperKind.photo,
      photoPath: '/tmp/a b.png',
      dimInDark: false,
    );
    expect(ChatWallpaper.decode(original.encode()), original);
  });

  test('garbage decodes to no wallpaper rather than throwing', () {
    expect(ChatWallpaper.decode('not json'), ChatWallpaper.none);
    expect(ChatWallpaper.decode(''), ChatWallpaper.none);
    expect(ChatWallpaper.decode(null), ChatWallpaper.none);
  });

  test('an unknown kind falls back to none', () {
    expect(
      ChatWallpaper.decode('{"kind":"hologram"}').kind,
      ChatWallpaperKind.none,
    );
  });

  test('dimming defaults on, because a bright photo at night is glaring', () {
    expect(
      ChatWallpaper.decode('{"kind":"preset","preset":"ink"}').dimInDark,
      isTrue,
    );
  });

  test('every preset id resolves and paints something', () {
    for (final preset in chatWallpaperPresets) {
      expect(chatWallpaperPresetById(preset.id), same(preset));
      expect(preset.colors, isNotEmpty);
      // One colour paints flat, two or more paint as a gradient.
      expect(preset.gradient == null, preset.colors.length < 2);
    }
  });

  test('preset ids are unique', () {
    final ids = chatWallpaperPresets.map((p) => p.id).toSet();
    expect(ids.length, chatWallpaperPresets.length);
  });
}
