import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';

/// Whether the server keeps this account's personal chats only until the
/// phones have them (`delivery_only` on /api/me, server 0173,
/// DELIVERY_ONLY.md). Every screen that promises a server copy — the
/// 120-day history, "can be downloaded again" — reads this before it says so.
/// False until the profile has loaded, and on a server that predates it.
final deliveryOnlyProvider = Provider<bool>(
  (ref) => ref.watch(profileProvider).valueOrNull?.deliveryOnly ?? false,
);

/// [key], or its `_delivery` wording while delivery-only is on. Both keys
/// exist in every language, so switching never shows a raw key.
String deliveryKey(String key, {required bool deliveryOnly}) =>
    deliveryOnly ? '${key}_delivery' : key;
