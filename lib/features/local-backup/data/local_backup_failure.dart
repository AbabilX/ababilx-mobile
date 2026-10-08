import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../format/backup_errors.dart';

/// A run that could not start or finish, named by the sentence the screen
/// shows. Kept apart from [BackupError], which is about a file's contents.
class LocalBackupFailure implements Exception {
  const LocalBackupFailure(this.messageKey);

  final String messageKey;

  static const noFolder = LocalBackupFailure('local_backup_error_folder');
  static const folderLost = LocalBackupFailure('local_backup_error_folder');
  static const nothingSelected = LocalBackupFailure(
    'local_backup_error_nothing',
  );
  static const locked = LocalBackupFailure('local_backup_error_locked');
  static const busy = LocalBackupFailure('local_backup_error_busy');
  static const folderRefused = LocalBackupFailure(
    'local_backup_error_folder_refused',
  );

  @override
  String toString() => 'LocalBackupFailure($messageKey)';
}

/// The translation key for whatever a run threw.
String localBackupFailureKey(Object error) => switch (error) {
  LocalBackupFailure(:final messageKey) => messageKey,
  BackupError(:final messageKey) => messageKey,
  // The key endpoint is the only network call a run makes.
  DioException() => 'local_backup_error_key',
  // Android's media folders take media only (Kotlin FolderRefusedException).
  PlatformException(code: 'folder_refused') =>
    'local_backup_error_folder_refused',
  // Only OUR channel's code means the folder. Any other PlatformException (a
  // crypto plugin, the message store) used to read as "could not use the
  // folder", which sent the hunt after folder names for a bug in HKDF.
  PlatformException(code: 'local_backup_failed') =>
    'local_backup_error_folder_io',
  // The automatic folder is written with plain file paths.
  FileSystemException() => 'local_backup_error_folder_io',
  _ => 'local_backup_error_generic',
};
