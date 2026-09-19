import 'dart:io';

import 'package:ababilx/features/messages/wallpaper/chat_wallpaper.dart';
import 'package:flutter/material.dart';
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
    expect(invisible.copyWith(opacity: 9).drawOpacity, 1);
  });

  test('unset always resolves to the built-in theme pair', () {
    expect(ChatWallpaper.decode(null).isSet, isFalse);
    expect(ChatWallpaper.none.effective.presetId, chatWallpaperMobileId);
    expect(ChatWallpaper.none.effective.dimInDark, isFalse);
    expect(ChatWallpaper.builtInDefault.presetId, chatWallpaperMobileId);
  });

  test('the paintings lead the grid and name real bundled files', () {
    final art = chatWallpaperPresets.where((p) => p.isArt).toList();
    expect(art.map((p) => p.id), [
      chatWallpaperMobileId,
      chatWallpaperDewdropId,
      chatWallpaperRainyPaddyId,
    ]);
    expect(chatWallpaperPresets.take(art.length), art);
    for (final preset in art) {
      expect(File(preset.asset!).existsSync(), isTrue, reason: preset.asset);
      if (preset.darkAsset != null) {
        expect(
          File(preset.darkAsset!).existsSync(),
          isTrue,
          reason: preset.darkAsset,
        );
      }
    }
  });

  test('the mobile preset swaps art with brightness', () {
    final mobile = chatWallpaperPresetById(chatWallpaperMobileId)!;
    expect(mobile.isThemePair, isTrue);
    expect(
      mobile.assetFor(Brightness.light),
      'assets/images/wallpapers/mobile_light.jpg',
    );
    expect(
      mobile.assetFor(Brightness.dark),
      'assets/images/wallpapers/mobile_dark.jpg',
    );
    expect(mobile.alignment, chatWallpaperPatternAlignment);
  });

  test('a single-art preset keeps the same file in dark theme', () {
    final dewdrop = chatWallpaperPresetById(chatWallpaperDewdropId)!;
    expect(dewdrop.isThemePair, isFalse);
    expect(
      dewdrop.assetFor(Brightness.light),
      dewdrop.assetFor(Brightness.dark),
    );
  });
}
