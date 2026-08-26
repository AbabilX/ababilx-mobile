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

/// Client-side mirror of `NormalizePhone` in
/// `ababilx-server/services/chat/access_connections.go`.
///
/// The server is the authority; this exists so the Save button can react as
/// the user types instead of round-tripping to learn the number was rejected.
/// A formatting normaliser, not a validator, and never proof of ownership —
/// there is no OTP behind it.
String? normalizePhoneNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  // The country code is required: without it the same digits mean different
  // people in different countries, and stored numbers are all E.164.
  if (!trimmed.startsWith('+')) return null;
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 8 || digits.length > 15) return null;
  return '+$digits';
}
