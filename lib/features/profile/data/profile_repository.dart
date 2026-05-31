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
      );

  @override
  List<Object?> get props => [id, name, plan, slackConnected];
}

class ProfileRepository {
  const ProfileRepository(this._client);
  final ApiClient _client;

  Future<AppUser> getMe() async {
    final res = await _client.get(ApiConstants.me);
    final data = (res.data as Map<String, dynamic>)['data'];
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AppUser> updateLanguage(String lang) async {
    final res = await _client.put(
      '${ApiConstants.me}/language',
      data: {'language': lang},
    );
    final data = (res.data as Map<String, dynamic>)['data'];
    return AppUser.fromJson(data as Map<String, dynamic>);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
