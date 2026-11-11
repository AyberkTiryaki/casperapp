import 'package:caspertrainingstudio/core/utils/formatters.dart';
import 'package:caspertrainingstudio/features/wallet/domain/wallet_models.dart';
import 'package:flutter_test/flutter_test.dart';

WalletEntry _e(int id, WalletEntryType t, {int? reverses}) => WalletEntry(
  id: id,
  memberId: 'm',
  type: t,
  amount: 10,
  balanceAfter: 10,
  createdAt: DateTime(2026),
  reversesEntryId: reverses,
);

void main() {
  test('parseMoney num ve String kabul eder', () {
    expect(parseMoney(12), 12.0);
    expect(parseMoney('12.50'), 12.5);
    expect(parseMoney(null), 0);
    expect(parseMoney('x'), 0);
  });

  test('parseMoneyInput en fazla 2 ondalık', () {
    expect(parseMoneyInput('10,5'), 10.5);
    expect(parseMoneyInput('-3.25'), -3.25);
    expect(parseMoneyInput('1.234'), isNull);
    expect(parseMoneyInput(''), isNull);
  });

  test('TL biçimi', () {
    expect(formatTl(1250.5), '1.250,50 ₺');
    expect(formatSignedTl(100), '+100 ₺');
    expect(formatSignedTl(-30), '-30 ₺');
  });

  test('hareket türü etiketleri', () {
    expect(WalletEntryType.fromString('topup').label, 'Yükleme');
    expect(WalletEntryType.fromString('purchase').label, 'Harcama');
    expect(WalletEntryType.fromString('reversal').label, 'Ters kayıt');
    expect(WalletEntryType.fromString('adjustment').label, 'Düzeltme');
  });

  test('canReverseEntry', () {
    final topup = _e(1, WalletEntryType.topup);
    final rev = _e(2, WalletEntryType.reversal, reverses: 1);
    final other = _e(3, WalletEntryType.purchase);
    final all = [other, rev, topup];
    expect(canReverseEntry(topup, all), isFalse);
    expect(canReverseEntry(rev, all), isFalse);
    expect(canReverseEntry(other, all), isTrue);
  });
}
