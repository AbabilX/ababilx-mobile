import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_repository.dart';

/// A pretend Ababil Pay balance, on this phone only. No money moves anywhere;
/// the sender's and the receiver's phones each keep their own number.
class DemoWalletRepository implements WalletRepository {
  const DemoWalletRepository();

  static const initialBalance = 10000.0;
  static const _balanceKey = 'ababilx_demo_wallet_balance';
  static const _refsKey = 'ababilx_demo_wallet_refs';

  /// The ledger only has to remember recent refs to stop a double tap or a
  /// reopen from paying twice.
  static const _maxRefs = 500;

  @override
  Future<double> balance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_balanceKey) ?? initialBalance;
  }

  @override
  Future<void> setBalance(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_balanceKey, _round(value < 0 ? 0 : value));
  }

  @override
  Future<void> debit(double amount, {required String ref}) =>
      _apply(-amount, 'debit:$ref');

  @override
  Future<void> credit(double amount, {required String ref}) =>
      _apply(amount, 'credit:$ref');

  Future<void> _apply(double delta, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final refs = prefs.getStringList(_refsKey) ?? const <String>[];
    if (refs.contains(key)) return;
    final current = prefs.getDouble(_balanceKey) ?? initialBalance;
    if (delta < 0 && current + delta < -0.001) {
      throw InsufficientBalance(current, -delta);
    }
    final next = [...refs, key];
    await prefs.setStringList(
      _refsKey,
      next.length > _maxRefs ? next.sublist(next.length - _maxRefs) : next,
    );
    await prefs.setDouble(_balanceKey, _round(current + delta));
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}
