import 'dart:io';

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

  test('opacity survives a round trip', () {
    const faded = ChatWallpaper(
      kind: ChatWallpaperKind.preset,
      presetId: 'ink',
      opacity: 0.45,
    );
    expect(ChatWallpaper.decode(faded.encode()), faded);
  });

  test('a wallpaper stored before opacity existed is fully opaque', () {
    final legacy = ChatWallpaper.decode(
      '{"kind":"preset","preset":"ink","dim":true}',
    );
    expect(legacy.opacity, 1);
    expect(legacy.drawOpacity, 1);
  });

  test('drawOpacity never lets a wallpaper vanish', () {
    const invisible = ChatWallpaper(
      kind: ChatWallpaperKind.preset,
      presetId: 'ink',
      opacity: 0,
    );
    expect(invisible.drawOpacity, chatWallpaperMinOpacity);
    // Out of range the other way too — nothing guarantees what was stored.
    expect(invisible.copyWith(opacity: 9).drawOpacity, 1);
  });

  test('nothing is applied until a person picks it', () {
    // The paintings are offered, never imposed: a chat with no stored choice
    // paints no wallpaper, exactly as it did before they were bundled.
    expect(ChatWallpaper.decode(null).isSet, isFalse);
    expect(ChatWallpaper.none.isSet, isFalse);
  });

  test('the paintings lead the grid and name real bundled files', () {
    final art = chatWallpaperPresets.where((p) => p.isArt).toList();
    expect(art.map((p) => p.id), [
      chatWallpaperDewdropId,
      chatWallpaperRainyPaddyId,
    ]);
    // Leading the list is what puts them on the first row of the picker.
    expect(chatWallpaperPresets.take(art.length), art);
    for (final preset in art) {
      expect(File(preset.asset!).existsSync(), isTrue, reason: preset.asset);
    }
  });
}
