import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_backup_settings.dart';

/// How a restore found waiting for this account is started.
enum RestoreOffer {
  /// A new install unlocked with the recovery code: restore without asking.
  automatic,

  /// "Start fresh" was chosen: the person decided to leave history behind
  /// a moment ago, so they are asked first.
  ask,
}

class LocalBackupSettingsStore {
  const LocalBackupSettingsStore();

  /// Android only: no other platform has the folder channel.
  static bool get automatic => defaultTargetPlatform == TargetPlatform.android;

  static String _key(String userId) => 'local_backup_v1_$userId';
  static String _legacyOfferKey(String userId) =>
      'local_backup_restore_offer_$userId';
  static String _offerKey(String userId) =>
      'local_backup_restore_offer_v2_$userId';

  Future<LocalBackupSettings> read(String userId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(userId),
      );
      return LocalBackupSettings.fromStored(
        raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map),
        automatic: automatic,
      );
    } catch (_) {
      return LocalBackupSettings.initial(automatic: automatic);
    }
  }

  Future<void> write(String userId, LocalBackupSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(settings.toJson()));
  }

  /// A restore is looked for only right after this phone got a new session
  /// for the account: the recovery code on a fresh install, or "start fresh"
  /// after losing it. Armed there, cleared once it was answered — so an
  /// ordinary app update never restores or asks anything. [ask] is never
  /// weakened to automatic by a later call.
  Future<void> armRestoreOffer(String userId, {bool ask = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ask && prefs.getString(_offerKey(userId)) == RestoreOffer.ask.name) {
      return;
    }
    await prefs.setString(
      _offerKey(userId),
      (ask ? RestoreOffer.ask : RestoreOffer.automatic).name,
    );
  }

  /// The offer still waiting, left in place: the scheduled backup holds off
  /// while one is, so a near-empty phone never replaces the backup it is
  /// about to restore from.
  Future<RestoreOffer?> pendingRestoreOffer(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_offerKey(userId));
    if (stored != null) {
      return RestoreOffer.values.where((o) => o.name == stored).firstOrNull;
    }
    // Armed by a build from before 2026-10-08, which stored a bool.
    if (prefs.get(_legacyOfferKey(userId)) == true) {
      await prefs.remove(_legacyOfferKey(userId));
      await prefs.setString(_offerKey(userId), RestoreOffer.automatic.name);
      return RestoreOffer.automatic;
    }
    return null;
  }

  Future<void> clearRestoreOffer(String userId) async =>
      (await SharedPreferences.getInstance()).remove(_offerKey(userId));
}
