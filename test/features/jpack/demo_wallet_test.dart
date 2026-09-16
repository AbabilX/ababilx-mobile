import 'package:ababilx/features/jpack/data/demo_wallet_repository.dart';
import 'package:ababilx/features/jpack/data/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const wallet = DemoWalletRepository();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts with the demo balance', () async {
    expect(await wallet.balance(), DemoWalletRepository.initialBalance);
  });

  test('a JPack is charged once however often it is sent', () async {
    await wallet.debit(500, ref: 'jp-1');
    await wallet.debit(500, ref: 'jp-1');
    expect(await wallet.balance(), 9500);
  });

  test('a JPack pays out once however often it is opened', () async {
    await wallet.credit(250.5, ref: 'jp-2');
    await wallet.credit(250.5, ref: 'jp-2');
    expect(await wallet.balance(), 10250.5);
  });

  test('refuses to go below zero', () async {
    await wallet.setBalance(100);
    expect(
      () => wallet.debit(100.01, ref: 'jp-3'),
      throwsA(isA<InsufficientBalance>()),
    );
    expect(await wallet.balance(), 100);
    // Refused, so the same ref can still go through later.
    await wallet.setBalance(200);
    await wallet.debit(100.01, ref: 'jp-3');
    expect(await wallet.balance(), 99.99);
  });
}
