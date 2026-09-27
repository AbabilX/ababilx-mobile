import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'backup_choices.dart';

/// One account's local-backup setup on THIS phone.
///
/// Keyed by user id, because it is opt-in per person: a second account signed
/// in on the same phone must not find its chats written into a folder
/// somebody else switched on. Device-local (SharedPreferences) like the
/// wallpaper and the auto-download matrix — a folder URI means nothing on
/// another phone.
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

  LocalBackupSettings copyWith({
    bool? enabled,
    String? folderUri,
    String? folderLabel,
    BackupChoices? choices,
    int? lastBackupMs,
    int? lastBackupBytes,
    String? lastFailureKey,
    bool clearFailure = false,
  }) => LocalBackupSettings(
    enabled: enabled ?? this.enabled,
    folderUri: folderUri ?? this.folderUri,
    folderLabel: folderLabel ?? this.folderLabel,
    choices: choices ?? this.choices,
    lastBackupMs: lastBackupMs ?? this.lastBackupMs,
    lastBackupBytes: lastBackupBytes ?? this.lastBackupBytes,
    lastFailureKey: clearFailure
        ? null
        : (lastFailureKey ?? this.lastFailureKey),
  );

  Map<String, dynamic> toJson() => {
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

class LocalBackupSettingsStore {
  const LocalBackupSettingsStore();

  static String _key(String userId) => 'local_backup_v1_$userId';
  static String _offerKey(String userId) =>
      'local_backup_restore_offer_$userId';

  Future<LocalBackupSettings> read(String userId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(userId),
      );
      if (raw == null) return const LocalBackupSettings();
      return LocalBackupSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const LocalBackupSettings();
    }
  }

  Future<void> write(String userId, LocalBackupSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(settings.toJson()));
  }

  /// "Restore from a backup?" is offered only right after this phone got a
  /// new session for the account: the recovery code on a fresh install, or
  /// "start fresh" after losing it. Armed there, taken (and cleared) by the
  /// one prompt — so an ordinary app update never asks anybody.
  Future<void> armRestoreOffer(String userId) async =>
      (await SharedPreferences.getInstance()).setBool(_offerKey(userId), true);

  Future<bool> takeRestoreOffer(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final armed = prefs.getBool(_offerKey(userId)) ?? false;
    if (armed) await prefs.remove(_offerKey(userId));
    return armed;
  }
}
