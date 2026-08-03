import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transfer_record.dart';

const _key = 'local_share_history_v1';
const _maxEntries = 200;

/// Persists completed/failed/canceled transfers so the History tab survives
/// an app restart — nothing in this feature was persisted before this.
class TransferHistoryStore {
  TransferHistoryStore._();

  static Future<List<TransferRecord>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(TransferRecord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Prepends [records] (newest first) and caps the stored list at
  /// [_maxEntries].
  static Future<List<TransferRecord>> add(List<TransferRecord> records) async {
    final existing = await read();
    final merged = [...records, ...existing].take(_maxEntries).toList();
    await _write(merged);
    return merged;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _write(List<TransferRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
