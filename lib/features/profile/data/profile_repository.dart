import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
    this.avatarUrl = '',
    this.plan = 'free',
    this.premiumUntil,
    this.effectivePlan = 'free',
    this.planExpired = false,
    this.showPlanExpiredDialog = false,
    this.slackConnected = false,
    this.githubUsername = '',
    this.appLanguage = 'en',
    this.acceptPolicy = true,
    this.policyVersion = '',
  });

  final String id;
  final String name;
  final String email;
  final String provider;
  final String avatarUrl;
  final String plan;
  final String? premiumUntil;
  final String effectivePlan;
  final bool planExpired;
  final bool showPlanExpiredDialog;
  final bool slackConnected;
  final String githubUsername;
  final String appLanguage;
  final bool acceptPolicy;
  final String policyVersion;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        plan: json['plan'] as String? ?? 'free',
        premiumUntil: json['premium_until'] as String?,
        effectivePlan: json['effective_plan'] as String? ??
            json['plan'] as String? ??
            'free',
        planExpired: json['plan_expired'] as bool? ?? false,
        showPlanExpiredDialog:
            json['show_plan_expired_dialog'] as bool? ?? false,
        slackConnected: json['slack_connected'] as bool? ?? false,
        githubUsername: json['github_username'] as String? ?? '',
        appLanguage: json['app_language'] as String? ?? 'en',
        acceptPolicy: json['accept_policy'] as bool? ?? true,
        policyVersion: json['policy_version'] as String? ?? '',
      );

  AppUser copyWith({bool? acceptPolicy, String? policyVersion}) => AppUser(
        id: id,
        name: name,
        email: email,
        provider: provider,
        avatarUrl: avatarUrl,
        plan: plan,
        premiumUntil: premiumUntil,
        effectivePlan: effectivePlan,
        planExpired: planExpired,
        showPlanExpiredDialog: showPlanExpiredDialog,
        slackConnected: slackConnected,
        githubUsername: githubUsername,
        appLanguage: appLanguage,
        acceptPolicy: acceptPolicy ?? this.acceptPolicy,
        policyVersion: policyVersion ?? this.policyVersion,
      );

  /// Merges split GET /api/me/* payloads (same order as web `mergeMeUser`).
  factory AppUser.fromMeParts({
    required Map<String, dynamic> session,
    required Map<String, dynamic> profile,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> connections,
  }) =>
      AppUser.fromJson({
        ...session,
        ...profile,
        ...plan,
        ...connections,
      });

  @override
  List<Object?> get props =>
      [id, name, plan, slackConnected, acceptPolicy, policyVersion];
}

class ProfileRepository {
  const ProfileRepository(this._client);
  final ApiClient _client;

  Future<AppUser> getMe() async {
    final sessionFuture = _getMePart(ApiConstants.me);
    final profileFuture = _getMePart(ApiConstants.meProfile);
    final planFuture = _getMePart(ApiConstants.mePlan);
    final connectionsFuture = _getMePart(ApiConstants.meConnections);

    final parts = await Future.wait([
      sessionFuture,
      profileFuture,
      planFuture,
      connectionsFuture,
    ]);

    return AppUser.fromMeParts(
      session: parts[0],
      profile: parts[1],
      plan: parts[2],
      connections: parts[3],
    );
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
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<void> acceptPolicy() async {
    await _client.post(ApiConstants.meAcceptPolicy);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
