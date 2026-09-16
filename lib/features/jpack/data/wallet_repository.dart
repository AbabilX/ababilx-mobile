/// Where JPack money comes from and goes to.
///
/// Today there is no wallet: [DemoWalletRepository] keeps a pretend balance on
/// this phone. When Ababil Pay exists, implement this against its API and swap
/// `walletRepositoryProvider` — nothing else in JPack reads the balance.
abstract class WalletRepository {
  Future<double> balance();

  /// Demo only: a real wallet will not let a client set its own balance.
  Future<void> setBalance(double value);

  /// Takes [amount] once per [ref]. Throws [InsufficientBalance] when the
  /// balance cannot cover it; repeating a ref that already went through is a
  /// no-op, not a second charge.
  Future<void> debit(double amount, {required String ref});

  /// Adds [amount] once per [ref].
  Future<void> credit(double amount, {required String ref});
}

class InsufficientBalance implements Exception {
  const InsufficientBalance(this.balance, this.amount);
  final double balance;
  final double amount;

  @override
  String toString() => 'InsufficientBalance($balance < $amount)';
}
