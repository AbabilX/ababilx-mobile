import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/jpack_opened_store.dart';

final jpackOpenedStoreProvider = Provider<JPackOpenedStore>(
  (ref) => const JPackOpenedStore(),
);

/// Auto-disposed, so a bubble that scrolls back into view re-reads the store —
/// an open that finished after its screen closed still shows as opened.
final jpackOpenedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.read(jpackOpenedStoreProvider).isOpened(id),
);
