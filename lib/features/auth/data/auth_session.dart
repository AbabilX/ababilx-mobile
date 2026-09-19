enum LocalAccountDecision { firstAccount, sameAccount, switchAccount }

LocalAccountDecision decideLocalAccount({
  required String newUserId,
  String? storedOwnerUserId,
  String? cachedOwnerUserId,
  bool hasUnownedPrivateData = false,
}) {
  final next = newUserId.trim();
  if (next.isEmpty) throw ArgumentError.value(newUserId, 'newUserId');
  final stored = storedOwnerUserId?.trim() ?? '';
  final cached = cachedOwnerUserId?.trim() ?? '';
  final current = stored.isNotEmpty ? stored : cached;
  if (current.isEmpty) {
    return hasUnownedPrivateData
        ? LocalAccountDecision.switchAccount
        : LocalAccountDecision.firstAccount;
  }
  return current == next
      ? LocalAccountDecision.sameAccount
      : LocalAccountDecision.switchAccount;
}

class PreparedAuthSession {
  const PreparedAuthSession({
    required this.accessToken,
    required this.userId,
    required this.user,
    this.refreshToken,
  });

  /// Reads the answer every sign-in endpoint gives: `access_token` (or the
  /// older `token`), `refresh_token`, and the `user` row.
  factory PreparedAuthSession.fromLoginBody(Map<String, dynamic> body) {
    if (body['success'] != true) {
      throw Exception(body['error']?.toString() ?? 'Login failed');
    }
    final jwt =
        body['access_token'] as String? ??
        body['token'] as String? ??
        body['data']?['token'] as String?;
    if (jwt == null) throw Exception('No token in server response');
    final rawUser = body['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    final userId = user['id']?.toString().trim() ?? '';
    if (userId.isEmpty) throw Exception('No user id in server response');
    return PreparedAuthSession(
      accessToken: jwt,
      refreshToken: body['refresh_token'] as String?,
      userId: userId,
      user: user,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final String userId;
  final Map<String, dynamic> user;

  String get accountLabel {
    final email = user['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;
    final name = user['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : userId;
  }
}

sealed class SignInOutcome {
  const SignInOutcome();
}

class SignInSucceeded extends SignInOutcome {
  const SignInSucceeded();
}

class SignInCancelled extends SignInOutcome {
  const SignInCancelled();
}

class SignInFailed extends SignInOutcome {
  const SignInFailed(this.error);
  final Object error;
}

class AccountSwitchRequired extends SignInOutcome {
  const AccountSwitchRequired(this.accountLabel);
  final String accountLabel;
}
