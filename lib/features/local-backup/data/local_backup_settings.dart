import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_choices.dart';

/// One account's local-backup setup on THIS phone.
///
/// Keyed by user id: a second account signed in on the same phone must not
/// find its chats written into a folder somebody else chose, nor inherit a
/// switch somebody else turned off. Device-local (SharedPreferences) like the
/// wallpaper and the auto-download matrix — a folder URI means nothing on
/// another phone.
///
/// **On by default since 2026-10-08** (Android): with no folder picked, the
/// backup goes to the automatic folder. [folderUri] set means the person
/// picked their own folder and keeps the single-file backup there.
class LocalBackupSettings {
  const LocalBackupSettings({
    this.enabled = false,
    this.folderUri,
    this.folderLabel,
    this.choices = const BackupChoices(),
    this.lastBackupMs,
    this.lastBackupBytes,
    this.lastFailureKey,
  });

  final bool enabled;
  final String? folderUri;
  final String? folderLabel;
  final BackupChoices choices;
  final int? lastBackupMs;
  final int? lastBackupBytes;

  /// Translation key of the last run's failure; cleared by a success.
  final String? lastFailureKey;

  bool get hasFolder => (folderUri ?? '').isNotEmpty;

  /// The settings of an account that never touched them.
  static LocalBackupSettings initial({required bool automatic}) =>
      LocalBackupSettings(enabled: automatic);

  /// What is stored, read under today's rule. Settings saved before the
  /// automatic backup existed carry no `auto` mark; "off" in those was the
  /// default nobody chose, so it becomes on — unless a folder was picked,
  /// which is a choice and is kept exactly.
  static LocalBackupSettings fromStored(
    Map<String, dynamic>? json, {
    required bool automatic,
  }) {
    if (json == null) return initial(automatic: automatic);
    final stored = LocalBackupSettings.fromJson(json);
    if (json['auto'] == true || stored.enabled || stored.hasFolder) {
      return stored;
    }
    return initial(automatic: automatic);
  }

  LocalBackupSettings copyWith({
    bool? enabled,
    String? folderUri,
    String? folderLabel,
    BackupChoices? choices,
    int? lastBackupMs,
    int? lastBackupBytes,
    String? lastFailureKey,
    bool clearFailure = false,
    bool clearFolder = false,
  }) => LocalBackupSettings(
    enabled: enabled ?? this.enabled,
    folderUri: clearFolder ? null : (folderUri ?? this.folderUri),
    folderLabel: clearFolder ? null : (folderLabel ?? this.folderLabel),
    choices: choices ?? this.choices,
    lastBackupMs: lastBackupMs ?? this.lastBackupMs,
    lastBackupBytes: lastBackupBytes ?? this.lastBackupBytes,
    lastFailureKey: clearFailure
        ? null
        : (lastFailureKey ?? this.lastFailureKey),
  );

  Map<String, dynamic> toJson() => {
    'auto': true,
    'enabled': enabled,
    'folder_uri': folderUri,
    'folder_label': folderLabel,
    'choices': choices.toJson(),
    'last_backup_ms': lastBackupMs,
    'last_backup_bytes': lastBackupBytes,
    'last_failure': lastFailureKey,
  };

  factory LocalBackupSettings.fromJson(Map<String, dynamic> json) =>
      LocalBackupSettings(
        enabled: json['enabled'] == true,
        folderUri: json['folder_uri'] as String?,
        folderLabel: json['folder_label'] as String?,
        choices: json['choices'] is Map
            ? BackupChoices.fromJson(
                Map<String, dynamic>.from(json['choices'] as Map),
              )
            : const BackupChoices(),
        lastBackupMs: (json['last_backup_ms'] as num?)?.toInt(),
        lastBackupBytes: (json['last_backup_bytes'] as num?)?.toInt(),
        lastFailureKey: json['last_failure'] as String?,
      );
}

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
