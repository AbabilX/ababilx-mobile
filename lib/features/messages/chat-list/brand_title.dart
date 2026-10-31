import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_link_up_provider.dart';
import '../../../shared/widgets/shimmer_mask.dart';

/// "AbabilX" in the chat list header. Shimmers while the realtime socket is
/// down, so a list that may be behind says so without a banner.
class ChatListBrandTitle extends ConsumerWidget {
  const ChatListBrandTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShimmerMask(
      active: !ref.watch(wsLinkUpProvider),
      child: Text(
        'AbabilX',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
