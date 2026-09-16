import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_wallet_repository.dart';
import '../data/jpack_claims_store.dart';
import '../data/wallet_repository.dart';

/// The one line to change when Ababil Pay has a real wallet.
final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => const DemoWalletRepository(),
);

class WalletBalanceNotifier extends AsyncNotifier<double> {
  WalletRepository get _repo => ref.read(walletRepositoryProvider);

  @override
  Future<double> build() => _repo.balance();

  Future<void> setBalance(double value) async {
    await _repo.setBalance(value);
    state = AsyncData(await _repo.balance());
  }

  Future<void> debit(double amount, {required String ref}) async {
    await _repo.debit(amount, ref: ref);
    state = AsyncData(await _repo.balance());
  }

  Future<void> credit(double amount, {required String ref}) async {
    await _repo.credit(amount, ref: ref);
    state = AsyncData(await _repo.balance());
  }
}

final walletBalanceProvider =
    AsyncNotifierProvider<WalletBalanceNotifier, double>(
      WalletBalanceNotifier.new,
    );

final jpackClaimsStoreProvider = Provider<JPackClaimsStore>(
  (ref) => const JPackClaimsStore(),
);

/// Auto-disposed, so a bubble that scrolls back into view re-reads the store —
/// an open that finished after its screen closed still shows as opened.
final jpackClaimedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.read(jpackClaimsStoreProvider).isClaimed(id),
);
