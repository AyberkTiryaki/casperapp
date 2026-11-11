import 'package:caspertrainingstudio/core/utils/error_messages.dart';
import 'package:caspertrainingstudio/core/utils/formatters.dart';
import 'package:caspertrainingstudio/core/utils/uuid.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_repo.dart';

void main() {
  test('validityDaysFor', () {
    expect(validityDaysFor(8), 30);
    expect(validityDaysFor(12), 30);
    expect(validityDaysFor(16), 40);
    expect(validityDaysFor(20), 40);
  });

  test('fromJson modelleri', () {
    final p = MemberPackage.fromJson({
      'id': 'p',
      'member_id': 'm',
      'definition_id': 'd',
      'category_id': 'c',
      'total_credits': 8,
      'remaining_credits': 3,
      'price_paid': 1250.5,
      'activated_at': '2026-11-01T10:00:00Z',
      'ends_at': '2026-12-01T10:00:00Z',
      'status': 'active',
      'package_definitions': {'name': 'Paket A'},
      'categories': {'name': 'Reformer'},
      'package_freezes': [
        {
          'id': 'f',
          'member_package_id': 'p',
          'starts_at': '2026-11-10T00:00:00Z',
          'ends_at': '2026-11-13T00:00:00Z',
          'days': 3,
        },
      ],
    });
    expect(p.definitionName, 'Paket A');
    expect(p.categoryName, 'Reformer');
    expect(p.freezes.single.days, 3);
    final d = PackageDefinition.fromJson({
      'id': 'd',
      'category_id': 'c',
      'name': 'X',
      'session_count': 16,
      'validity_days': 40,
      'price': 100,
      'is_active': false,
      'categories': {'name': 'Mat'},
    });
    expect(d.categoryName, 'Mat');
    expect(d.isActive, false);
    final e = CreditLedgerEntry.fromJson({
      'id': 5,
      'entry_type': 'transfer_in',
      'delta': 4,
      'balance_after': 9,
      'created_at': '2026-11-01T10:00:00Z',
    });
    expect(e.label, 'Aktarım (yeni pakete giriş)');
    final b = CreditLedgerEntry.fromJson({
      'id': 1,
      'entry_type': 'booking',
      'delta': -1,
      'balance_after': 0,
      'created_at': '2026-11-01T10:00:00Z',
    });
    expect(b.label, 'Rezervasyon');
  });

  test('displayStatus', () {
    final now = DateTime.now();
    expect(samplePackage().displayStatus(now), PackageDisplayStatus.active);
    expect(
      samplePackage(endsIn: const Duration(days: -1)).displayStatus(now),
      PackageDisplayStatus.expired,
    );
    expect(
      samplePackage(status: 'terminated').displayStatus(now),
      PackageDisplayStatus.terminated,
    );
    final frozen = samplePackage(
      freezes: [
        PackageFreeze(
          id: 'f',
          memberPackageId: 'p1',
          startsAt: now.subtract(const Duration(days: 1)),
          endsAt: now.add(const Duration(days: 2)),
          days: 3,
        ),
      ],
    );
    expect(frozen.displayStatus(now), PackageDisplayStatus.frozen);
    expect(samplePackage().daysLeft(now), inInclusiveRange(19, 20));
  });

  test('hata kodu eşlemesi', () {
    String m(String code) => friendlyError(PostgrestException(message: code));
    expect(m('ACTIVE_PACKAGE_EXISTS'), contains('aktif bir paket'));
    expect(m('FREEZE_OVERLAP'), contains('dondurma'));
    expect(m('FORBIDDEN'), contains('yetkiniz'));
    expect(
      friendlyError(const PostgrestException(message: 'x', code: '23505')),
      'Bu kayıt zaten var.',
    );
    expect(
      friendlyError(const PostgrestException(message: 'x', code: '23514')),
      'Girilen değerler kurallara uymuyor.',
    );
    expect(
      friendlyError(const PostgrestException(message: 'x', code: '42501')),
      'Bu işlem için yetkiniz yok.',
    );
  });

  test('uuid v4 biçimi', () {
    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final a = generateUuidV4();
    expect(re.hasMatch(a), isTrue);
    expect(generateUuidV4(), isNot(a));
  });

  test('formatTl ve parseDecimal', () {
    expect(formatTl(1250), '1.250 ₺');
    expect(formatTl(1250.5), '1.250,50 ₺');
    expect(parseDecimal('1250,5'), 1250.5);
    expect(formatDate(DateTime(2026, 3, 5)), '05.03.2026');
  });
}
