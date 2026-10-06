import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
    this.username = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.githubUsername = '',
    this.appLanguage = 'en',
    this.acceptPolicy = true,
    this.policyVersion = '',
    this.independentChat = false,
    this.isNewAccount = false,
    this.encryptedAttachments = false,
  });

  final String id;
  final String name;
  final String email;
  final String provider;

  /// The AbabilX handle — what a personal QR code carries. Empty until the
  /// user picks one; `githubUsername` is a different field and never stands in
  /// for it, because a GitHub login is not an address on this app.
  final String username;
  final String avatarUrl;

  /// Wide profile cover (`users.cover_url`). Same object the DM details
  /// header draws behind the other person's avatar.
  final String coverUrl;
  final String githubUsername;
  final String appLanguage;
  final bool acceptPolicy;
  final String policyVersion;
  final bool independentChat;

  /// True only inside the server's onboarding window right after signup
  /// (`db.NewAccountWindow`, server). Gates a permission ask that would
  /// otherwise read as a blitz on a brand-new sign-up — never re-derive this
  /// from local state, it has to be the server's own clock.
  final bool isNewAccount;

  /// Whether the server takes chat files encrypted on the phone before
  /// upload (server migration 0168). Always true on a current server; false
  /// only from one that predates 0168 and would store the ciphertext without
  /// its key. Decides sending only — an encrypted file that arrives is
  /// opened whatever this says.
  final bool encryptedAttachments;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    username: json['username'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String? ?? '',
    coverUrl: json['cover_url'] as String? ?? '',
    githubUsername: json['github_username'] as String? ?? '',
    appLanguage: json['app_language'] as String? ?? 'en',
    acceptPolicy: json['accept_policy'] as bool? ?? true,
    policyVersion: json['policy_version'] as String? ?? '',
    independentChat: json['independent_chat'] as bool? ?? false,
    isNewAccount: json['is_new_account'] as bool? ?? false,
    encryptedAttachments: json['encrypted_attachments'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'provider': provider,
    'username': username,
    'avatar_url': avatarUrl,
    'cover_url': coverUrl,
    'github_username': githubUsername,
    'app_language': appLanguage,
    'accept_policy': acceptPolicy,
    'policy_version': policyVersion,
    'independent_chat': independentChat,
    'is_new_account': isNewAccount,
    'encrypted_attachments': encryptedAttachments,
  };

  AppUser copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? coverUrl,
    bool? acceptPolicy,
    String? policyVersion,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email,
    provider: provider,
    username: username ?? this.username,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    githubUsername: githubUsername,
    appLanguage: appLanguage,
    acceptPolicy: acceptPolicy ?? this.acceptPolicy,
    policyVersion: policyVersion ?? this.policyVersion,
    independentChat: independentChat,
    isNewAccount: isNewAccount,
    encryptedAttachments: encryptedAttachments,
  );

  /// Merges split GET /api/me/* payloads (same order as web `mergeMeUser`).
  factory AppUser.fromMeParts({
    required Map<String, dynamic> session,
    required Map<String, dynamic> profile,
  }) => AppUser.fromJson({...session, ...profile});

  @override
  List<Object?> get props => [
    id,
    name,
    username,
    avatarUrl,
    coverUrl,
    acceptPolicy,
    policyVersion,
    independentChat,
    isNewAccount,
    encryptedAttachments,
  ];
}

class ProfileRepository {
  const ProfileRepository(this._client);
  final ApiClient _client;

  static const _cacheKey = 'ababilx_cached_user_profile';

  Future<AppUser> getMe() async {
    try {
      final sessionFuture = _getMePart(ApiConstants.me);
      final profileFuture = _getMePart(ApiConstants.meProfile);

      final parts = await Future.wait([sessionFuture, profileFuture]);

      final user = AppUser.fromMeParts(session: parts[0], profile: parts[1]);

      // Persist to local cache for instant offline restore
      await _cacheUser(user);
      return user;
    } catch (_) {
      // Fallback to local cache when offline
      final cached = await getCachedMe();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<AppUser?> getCachedMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(user.toJson()));
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

  Future<Map<String, dynamic>> _getMePart(String path) async {
    final res = await _client.get(path);
    final data = (res.data as Map<String, dynamic>)['data'];
    return data as Map<String, dynamic>;
  }

  Future<AppUser> updateLanguage(String lang) async {
    final res = await _client.put(
      '${ApiConstants.me}/language',
      data: {'language': lang},
    );
    final data = (res.data as Map<String, dynamic>)['data'];
    final updated = AppUser.fromJson(data as Map<String, dynamic>);
    await _cacheUser(updated);
    return updated;
  }

  Future<void> acceptPolicy() async {
    await _client.post(ApiConstants.meAcceptPolicy);
  }

  /// Sets the name everyone else sees and returns the value the server
  /// actually stored.
  ///
  /// The server normalizes (collapses whitespace runs, strips invisible
  /// characters), so echoing the typed string back into local state would
  /// leave the phone showing something the rest of the world does not see.
  /// Falls back to the trimmed input only if an older server answers without
  /// the profile body.
  Future<String> updateName(String name) async {
    final res = await _client.put(ApiConstants.meName, data: {'name': name});
    final data = (res.data as Map<String, dynamic>)['data'];
    if (data is Map<String, dynamic>) {
      final stored = (data['name'] as String? ?? '').trim();
      if (stored.isNotEmpty) return stored;
    }
    return name.trim();
  }

  /// Writes a locally-patched profile straight to the offline cache, so an
  /// edit survives a cold restart without waiting for the next GET /me.
  Future<void> cacheUser(AppUser user) => _cacheUser(user);
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
