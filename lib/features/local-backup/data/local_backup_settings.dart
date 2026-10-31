import 'backup_choices.dart';
import 'backup_file_name.dart';
import 'backup_schedule.dart';

export 'local_backup_settings_store.dart';

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
    this.backupMinute = defaultBackupMinute,
    this.fileName = '',
  });

  final bool enabled;
  final String? folderUri;
  final String? folderLabel;
  final BackupChoices choices;
  final int? lastBackupMs;
  final int? lastBackupBytes;

  /// Translation key of the last run's failure; cleared by a success.
  final String? lastFailureKey;

  /// The time of day of the daily automatic run — see `backup_schedule.dart`.
  final int backupMinute;

  /// The name the person gave the backup file; empty is the automatic one.
  final String fileName;

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
    int? backupMinute,
    String? fileName,
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
    backupMinute: backupMinute ?? this.backupMinute,
    fileName: fileName ?? this.fileName,
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
    'backup_minute': backupMinute,
    'file_name': fileName,
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
        backupMinute: backupMinuteFrom(json['backup_minute']),
        fileName: json['file_name'] is String
            ? cleanBackupName(json['file_name'] as String)
            : '',
      );
}
