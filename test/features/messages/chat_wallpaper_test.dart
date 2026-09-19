import 'dart:io';

import 'package:ababilx/features/messages/wallpaper/chat_wallpaper.dart';
import 'package:ababilx/features/messages/wallpaper/chat_wallpaper_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test(
    'nothing is applied until a person picks it (or a fresh install ships)',
    () {
      // Decode itself never invents a wallpaper; shipping the default is a
      // separate store step for brand-new installs only.
      expect(ChatWallpaper.decode(null).isSet, isFalse);
      expect(ChatWallpaper.none.isSet, isFalse);
    },
  );

  test('the paintings lead the grid and name real bundled files', () {
    final art = chatWallpaperPresets.where((p) => p.isArt).toList();
    expect(art.map((p) => p.id), [
      chatWallpaperMobileId,
      chatWallpaperDewdropId,
      chatWallpaperRainyPaddyId,
    ]);
    // Leading the list is what puts them on the first row of the picker.
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

  group('shipDefaultIfFreshInstall', () {
    const store = ChatWallpaperStore();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('fresh install gets the mobile theme pair', () async {
      await store.shipDefaultIfFreshInstall();
      final global = await store.readGlobal();
      expect(global.kind, ChatWallpaperKind.preset);
      expect(global.presetId, chatWallpaperMobileId);
      expect(global.dimInDark, isFalse);
    });

    test('upgrade with onboarding seen stays plain', () async {
      SharedPreferences.setMockInitialValues({
        'messaging_onboarding_v1_seen': true,
      });
      await store.shipDefaultIfFreshInstall();
      expect((await store.readGlobal()).isSet, isFalse);
    });

    test('does not overwrite an existing global choice', () async {
      SharedPreferences.setMockInitialValues({});
      await store.writeGlobal(ChatWallpaper.preset('ink'));
      // Writing the global key counts as a returning install (`ababilx_*`).
      await store.shipDefaultIfFreshInstall();
      expect((await store.readGlobal()).presetId, 'ink');
    });

    test('second call is a no-op even after clearing wallpaper', () async {
      await store.shipDefaultIfFreshInstall();
      await store.writeGlobal(ChatWallpaper.none);
      await store.shipDefaultIfFreshInstall();
      expect((await store.readGlobal()).isSet, isFalse);
    });
  });
}
