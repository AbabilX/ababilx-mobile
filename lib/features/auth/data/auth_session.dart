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

sealed class GoogleSignInOutcome {
  const GoogleSignInOutcome();
}

class GoogleSignInSucceeded extends GoogleSignInOutcome {
  const GoogleSignInSucceeded();
}

class GoogleSignInCancelled extends GoogleSignInOutcome {
  const GoogleSignInCancelled();
}

class GoogleSignInFailed extends GoogleSignInOutcome {
  const GoogleSignInFailed(this.error);
  final Object error;
}

class GoogleAccountSwitchRequired extends GoogleSignInOutcome {
  const GoogleAccountSwitchRequired(this.accountLabel);
  final String accountLabel;
}
