import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import 'models/call_log_entry.dart';

/// Call history brought back from a local backup — Signal's call log lives on
/// the phone, so a restore brings it back with the messages, offline and
/// after the server has forgotten the calls.
///
/// One file, stamped with the account it belongs to, merged under whatever
/// the server returns ([withRestoredCalls]). Written only by a restore and
/// read back into the next backup, so a second restore keeps it too. An
/// account switch deletes it ([AccountDataWiper]).
class RestoredCallLog {
  const RestoredCallLog(this._owner);

  /// Newest kept; a call log past this is history nobody scrolls to.
  static const maxCalls = 5000;

  final Future<String?> Function() _owner;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/call_log/restored_v1.json');
  }

  Future<List<CallLogEntry>> read() async {
    try {
      final owner = (await _owner())?.trim() ?? '';
      if (owner.isEmpty) return const [];
      final file = await _file();
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString()) as Map;
      if (json['owner'] != owner) return const [];
      return [
        for (final raw in json['calls'] as List)
          CallLogEntry.fromJson(Map<String, dynamic>.from(raw as Map)),
      ];
    } catch (error) {
      debugPrint('[RestoredCallLog] unreadable: $error');
      return const [];
    }
  }

  /// Adds [calls] to what is kept (by id; a newer copy of a row wins).
  Future<void> merge(String owner, List<CallLogEntry> calls) async {
    if (owner.isEmpty || calls.isEmpty) return;
    final byId = {for (final c in await read()) c.id: c};
    for (final c in calls) {
      if (c.id.isNotEmpty) byId[c.id] = c;
    }
    final all = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final file = await _file();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'owner': owner,
        'calls': [for (final c in all.take(maxCalls)) c.toJson()],
      }),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// [server] with the restored rows laid in, newest first. While older server
/// pages are still to come ([hasMore]), only restored rows inside the span
/// already loaded join — one further back would sit above calls that page
/// has not brought yet.
List<CallLogEntry> withRestoredCalls(
  List<CallLogEntry> server,
  List<CallLogEntry> restored, {
  required bool hasMore,
}) {
  if (restored.isEmpty) return server;
  final seen = {for (final c in server) c.id};
  final oldest = server.isEmpty ? null : server.last.startedAt;
  final extra = [
    for (final c in restored)
      if (!seen.contains(c.id) &&
          (!hasMore || oldest == null || !c.startedAt.isBefore(oldest)))
        c,
  ];
  if (extra.isEmpty) return server;
  return [...server, ...extra]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
}

final restoredCallLogProvider = Provider<RestoredCallLog>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return RestoredCallLog(storage.readLocalDataOwnerUserId);
});
