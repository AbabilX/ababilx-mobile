import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/team_models.dart';

class TeamRepository {
  const TeamRepository(this._client);
  final ApiClient _client;

  static const _cacheKey = 'ababilx_cached_my_team';

  Future<TeamDetail?> getMyTeam() async {
    try {
      final res = await _client.get(ApiConstants.teamsMe);
      final data = unwrapApiData<Map<String, dynamic>?>(res);
      if (data == null) {
        await clearCache();
        return null;
      }
      final detail = TeamDetail.fromJson(data);
      if (detail.hasTeam) {
        await _cacheTeam(detail);
        return detail;
      }
      await clearCache();
      return null;
    } catch (_) {
      // Return cached team if network is unavailable
      final cached = await getCachedTeam();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<TeamDetail?> getCachedTeam() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final detail = TeamDetail.fromJson(json);
      return detail.hasTeam ? detail : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheTeam(TeamDetail detail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(detail.toJson()));
    } catch (_) {}
  }

  Future<void> clearCache({bool strict = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {
      if (strict) rethrow;
    }
  }
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(apiClientProvider)),
);
