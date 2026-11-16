import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/packages/presentation/admin/member_packages_screen.dart';
import 'package:caspertrainingstudio/features/packages/presentation/shared/package_widgets.dart';
import 'package:caspertrainingstudio/features/protocols/data/protocol_repository.dart';
import 'package:caspertrainingstudio/features/protocols/domain/protocol_models.dart';
import 'package:caspertrainingstudio/features/protocols/presentation/admin_protocols_screen.dart';
import 'package:caspertrainingstudio/features/protocols/presentation/price_list_screen.dart';
import 'package:caspertrainingstudio/features/referrals/data/referral_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart'
    show ClassType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../packages/fake_repo.dart';
import '../referrals/referrals_test.dart' show FakeReferralRepository;
import 'fake_protocol_repo.dart';

MemberPackage pkgWith({required int total, required int proto}) =>
    MemberPackage(
      id: 'p',
      memberId: 'm',
      definitionId: 'd',
      categoryId: 'c',
      totalCredits: 8,
      remainingCredits: 8,
      pricePaid: 800,
      listPrice: 1000,
      discountPercent: total,
      protocolDiscountPercent: proto,
      activatedAt: DateTime(2026, 11, 1),
      endsAt: DateTime(2026, 12, 1),
      status: 'active',
    );

void main() {
  group('indirim hesabı', () {
    test('referans ve protokol toplanır, tavan %50', () {
      expect(combinedDiscount(0, 0), 0);
      expect(combinedDiscount(5, 15), 20);
      expect(combinedDiscount(40, 15), 50);
      expect(combinedDiscount(0, 50), 50);
    });

    test('indirimli fiyat 2 ondalığa yuvarlanır', () {
      expect(discountedPrice(4000, 30), 2800);
      expect(discountedPrice(999.99, 15), 849.99);
      expect(discountedPrice(1000, 0), 1000);
    });

    test('paket kartı indirim kırılımı', () {
      expect(discountBreakdown(pkgWith(total: 10, proto: 0)), 'İndirim: %10');
      expect(
        discountBreakdown(pkgWith(total: 15, proto: 15)),
        'İndirim: %15 (protokol)',
      );
      expect(
        discountBreakdown(pkgWith(total: 20, proto: 15)),
        'İndirim: %20 (referans %5 + protokol %15)',
      );
    });
  });

  group('Protocol', () {
    final now = DateTime(2026, 11, 16, 15);

    test('geçerlilik: aktif ve son gün dahil', () {
      Protocol p({bool active = true, DateTime? until}) => Protocol(
        id: 'x',
        name: 'X',
        discountPercent: 10,
        isActive: active,
        validUntil: until,
      );
      expect(p().isValidOn(now), isTrue);
      expect(p(until: DateTime(2026, 11, 16)).isValidOn(now), isTrue);
      expect(p(until: DateTime(2026, 11, 15)).isValidOn(now), isFalse);
      expect(p(active: false).isValidOn(now), isFalse);
    });

    test('JSON okuma', () {
      final p = Protocol.fromJson({
        'id': 'a',
        'name': 'X Sendikası',
        'discount_percent': 15,
        'is_active': true,
        'valid_until': '2026-12-31',
        'note': 'Belge: üye kartı',
      });
      expect(p.name, 'X Sendikası');
      expect(p.discountPercent, 15);
      expect(p.validUntil, DateTime(2026, 12, 31));
      expect(protocolStatusText(p, now), 'Aktif · 31.12.2026 tarihine kadar');
    });

    test('oran doğrulaması 1-50', () {
      expect(validateProtocolPercent('15'), isNull);
      expect(validateProtocolPercent('0'), isNotNull);
      expect(validateProtocolPercent('51'), isNotNull);
      expect(validateProtocolPercent('abc'), isNotNull);
    });

    test('herkese açık liste JSON', () {
      final l = PublicPriceList.fromJson({
        'categories': [
          {
            'id': 'c',
            'name': 'Reformer',
            'class_type': 'group',
            'packages': [
              {
                'id': 'd',
                'name': '8 Ders',
                'session_count': 8,
                'validity_days': 30,
                'price': 4000,
              },
            ],
          },
        ],
        'protocols': [
          {'name': 'X Sendikası', 'discount_percent': 15, 'valid_until': null},
        ],
      });
      expect(l.categories.single.packages.single.price, 4000);
      expect(l.protocols.single.discountPercent, 15);
      expect(l.isEmpty, isFalse);
    });
  });

  Widget wrap(FakeProtocolRepository repo, Widget home) => ProviderScope(
    overrides: [protocolRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: home),
  );

  testWidgets('Fiyat listesi paketleri ve kurum indirimlerini gösterir', (
    tester,
  ) async {
    final repo = FakeProtocolRepository()
      ..priceList = const PublicPriceList(
        categories: [
          PublicCategory(
            name: 'Reformer Pilates',
            classType: ClassType.group,
            packages: [
              PublicPackage(
                name: '8 Derslik Paket',
                sessionCount: 8,
                validityDays: 30,
                price: 4000,
              ),
            ],
          ),
        ],
        protocols: [PublicProtocol(name: 'X Sendikası', discountPercent: 15)],
      );
    await tester.pumpWidget(wrap(repo, const PriceListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Reformer Pilates'), findsOneWidget);
    expect(find.text('Grup dersi'), findsOneWidget);
    expect(find.text('8 ders · 30 gün geçerli'), findsOneWidget);
    expect(find.textContaining('4.000'), findsOneWidget);
    expect(find.text('Kurum indirimleri'), findsOneWidget);
    expect(find.text('X Sendikası'), findsOneWidget);
    expect(find.text('%15 indirim'), findsOneWidget);
    expect(find.text('Tüm fiyatlara KDV dahildir.'), findsOneWidget);
    expect(find.text('Paketler ve Fiyatlar'), findsOneWidget);
  });

  testWidgets('Fiyat listesi boşsa bilgi mesajı', (tester) async {
    await tester.pumpWidget(
      wrap(FakeProtocolRepository(), const PriceListScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fiyat listesi henüz hazır değil'), findsOneWidget);
  });

  testWidgets('Protokol ekle: form doğrular ve kaydeder', (tester) async {
    final repo = FakeProtocolRepository();
    await tester.pumpWidget(wrap(repo, const AdminProtocolsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Protokol yok'), findsOneWidget);
    await tester.tap(find.text('Protokol ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Ad gerekli.'), findsOneWidget);
    expect(repo.saveCalls, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kurum adı'),
      'X Sendikası',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'İndirim oranı (%)'),
      '15',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repo.saveCalls.single['name'], 'X Sendikası');
    expect(repo.saveCalls.single['discount_percent'], 15);
    expect(repo.saveCalls.single['valid_until'], isNull);
    expect(find.text('Protokol kaydedildi.'), findsOneWidget);
  });

  testWidgets('Üye kartında protokole bağlama', (tester) async {
    final protoRepo = FakeProtocolRepository()
      ..protocols = [
        const Protocol(
          id: 'px',
          name: 'X Sendikası',
          discountPercent: 15,
          isActive: true,
        ),
        const Protocol(
          id: 'off',
          name: 'Pasif Dernek',
          discountPercent: 10,
          isActive: false,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packageRepositoryProvider.overrideWithValue(FakePackageRepository()),
          referralRepositoryProvider.overrideWithValue(
            FakeReferralRepository(),
          ),
          protocolRepositoryProvider.overrideWithValue(protoRepo),
        ],
        child: const MaterialApp(
          home: AdminMemberPackagesScreen(
            member: MemberSummary(id: 'm1', fullName: 'Ayşe Yılmaz'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bağlı protokol yok'), findsOneWidget);
    await tester.tap(find.text('Bağla'));
    await tester.pumpAndSettle();
    // Pasif protokol seçeneklerde yok
    expect(find.text('Pasif Dernek (%10)'), findsNothing);
    await tester.tap(find.text('X Sendikası (%15)'));
    await tester.pumpAndSettle();
    expect(protoRepo.setCalls.single.protocolId, 'px');
    expect(
      find.text('X Sendikası: %15, paket atamada otomatik uygulanır'),
      findsOneWidget,
    );
  });
}
