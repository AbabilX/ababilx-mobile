import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../privacy_mode_provider.dart';
import 'privacy_people_provider.dart';
import 'privacy_person.dart';

/// Whether this account's privacy mode applies toward one person: their own
/// choice when there is one, else the switch. The client half of the
/// server's `db.PrivateToSQL` — the two must agree, or the photo sheet shows
/// up for someone the server treats as exempt (or, worse, not for someone it
/// hides from).
final privacyTowardProvider = Provider.family<bool, String>((ref, userId) {
  final mode =
      ref.watch(privacyPeopleProvider.select((m) => m[userId]?.mode)) ??
      PrivacyPersonMode.follow;
  return mode.appliesWith(switchOn: ref.watch(privacyModeProvider));
});

/// [privacyTowardProvider], after both halves have had their first load.
/// What a send path asks, so an offline cold start cannot answer with the
/// not-yet-loaded defaults.
Future<bool> resolvePrivacyToward(WidgetRef ref, String userId) async {
  final (switchOn, people) = await (
    ref.read(privacyModeProvider.notifier).resolve(),
    ref.read(privacyPeopleProvider.notifier).resolve(),
  ).wait;
  final mode = people[userId]?.mode ?? PrivacyPersonMode.follow;
  return mode.appliesWith(switchOn: switchOn);
}
