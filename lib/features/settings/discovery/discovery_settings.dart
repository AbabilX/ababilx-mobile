import 'package:equatable/equatable.dart';

/// Who is allowed to find this account in people search.
///
/// These matter more than they look: anyone who can find you can open a chat
/// with you, because messaging no longer waits for an accepted connection —
/// the person on the other end answers a message request instead.
class DiscoverySettings extends Equatable {
  const DiscoverySettings({
    this.phoneNumber = '',
    this.byUsername = false,
    this.byEmail = true,
    this.byPhone = true,
  });

  /// Stored in E.164 ("+8801712345678"). Never verified, never used for
  /// sign-in or recovery — discovery only.
  final String phoneNumber;

  /// Off by default for accounts created after migration 0108: a handle is
  /// short and matched as a prefix, so it is guessable in a way an exact
  /// email or phone is not.
  final bool byUsername;
  final bool byEmail;
  final bool byPhone;

  factory DiscoverySettings.fromJson(Map<String, dynamic> json) =>
      DiscoverySettings(
        phoneNumber: (json['phone_number'] as String? ?? '').trim(),
        byUsername: json['discoverable_by_username'] as bool? ?? false,
        byEmail: json['discoverable_by_email'] as bool? ?? true,
        byPhone: json['discoverable_by_phone'] as bool? ?? true,
      );

  DiscoverySettings copyWith({
    String? phoneNumber,
    bool? byUsername,
    bool? byEmail,
    bool? byPhone,
  }) => DiscoverySettings(
    phoneNumber: phoneNumber ?? this.phoneNumber,
    byUsername: byUsername ?? this.byUsername,
    byEmail: byEmail ?? this.byEmail,
    byPhone: byPhone ?? this.byPhone,
  );

  @override
  List<Object?> get props => [phoneNumber, byUsername, byEmail, byPhone];
}
