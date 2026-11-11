import 'package:caspertrainingstudio/core/utils/error_messages.dart';
import 'package:caspertrainingstudio/features/auth/data/auth_repository.dart';
import 'package:caspertrainingstudio/features/auth/validators.dart';
import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/packages/presentation/admin/member_packages_screen.dart';
import 'package:caspertrainingstudio/features/referrals/data/referral_repository.dart';
import 'package:caspertrainingstudio/features/referrals/domain/referral_models.dart';
import 'package:caspertrainingstudio/features/referrals/presentation/admin_referrals_screen.dart';
import 'package:caspertrainingstudio/features/referrals/presentation/my_referrals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../packages/fake_repo.dart';

class FakeReferralRepository implements ReferralRepository {
  ReferralSummary summaryData = const ReferralSummary(
    userId: 'm1',
    referralCode: 'ABCDEFG',
    activeCount: 0,
    discountPercent: 0,
    approvedCount: 0,
    pendingCount: 0,
    wasReferred: true,
  );
  List<MyReferral> mine = [];
  List<AdminReferral> admin = [];
  final decideCalls = <(String, bool)>[];
  int adminListCalls = 0;

  @override
  Future<ReferralSummary> summary({String? userId}) async => summaryData;
  @override
  Future<List<MyReferral>> myReferrals() async => mine;
  @override
  Future<List<AdminReferral>> adminList({String? status}) async {
    adminListCalls++;
    return admin;
  }

  @override
  Future<void> decide({
    required String referralId,
    required bool approve,
    String? note,
  }) async {
    decideCalls.add((referralId, approve));
  }
}

void main() {
  test('referans modelleri fromJson', () {
    final s = ReferralSummary.fromJson({
      'user_id': 'u',
      'referral_code': 'ABCDEFG',
      'active_count': 3,
      'discount_percent': 15,
      'approved_count': 4,
      'pending_count': 1,
      'was_referred': true,
    });
    expect(s.discountPercent, 15);
    expect(s.wasReferred, true);
    final m = MyReferral.fromJson({
      'referral_id': 'r',
      'display_name': 'Ayşe K.',
      'status': 'approved',
      'counts_now': true,
      'created_at': '2026-11-01T10:00:00Z',
    });
    expect(m.status, ReferralStatus.approved);
    expect(m.status.label, 'Onaylandı');
    expect(ReferralStatus.pending.label, 'Beklemede');
    expect(ReferralStatus.rejected.label, 'Reddedildi');
    final a = AdminReferral.fromJson({
      'id': 'x',
      'referrer_id': 'a',
      'referrer_name': 'A B',
      'referrer_code': 'ABCDEFG',
      'referrer_discount_percent': 10,
      'referred_id': 'b',
      'referred_name': 'C D',
      'referred_has_active_package': true,
      'status': 'pending',
      'created_at': '2026-11-01T10:00:00Z',
    });
    expect(a.referredHasActivePackage, true);
    expect(a.decidedAt, isNull);
  });

  test('referans kodu doğrulama ve normalleştirme', () {
    expect(normalizeReferralCode(' ab cd 234 '), 'ABCD234');
    expect(validateReferralCode(''), isNull);
    expect(validateReferralCode(null), isNull);
    expect(validateReferralCode('abcdefg'), isNull);
    expect(validateReferralCode('ABCDEF'), isNotNull);
    expect(validateReferralCode('ABCDEFI'), isNotNull); // I alfabede yok
    expect(validateReferralCode('ABCDEF0'), isNotNull); // 0 alfabede yok
  });

  test('kayıt metadata referans kodunu normalize eder', () {
    SignUpData d(String? code) => SignUpData(
      email: 'a@b.co',
      password: '12345678',
      fullName: 'Ayşe Yılmaz',
      birthDate: DateTime(1990, 5, 17),
      heightCm: 170,
      weightKg: 60,
      referralCode: code,
    );
    expect(buildSignUpMetadata(d(' abc defg '))['referral_code'], 'ABCDEFG');
    expect(buildSignUpMetadata(d('  ')).containsKey('referral_code'), false);
    expect(buildSignUpMetadata(d(null)).containsKey('referral_code'), false);
    expect(buildSignUpMetadata(d(null))['birth_date'], '1990-05-17');
  });

  test('geçersiz kod uyarısı kararı', () {
    expect(
      shouldShowInvalidReferralWarning(signupCode: 'ABC', wasReferred: false),
      true,
    );
    expect(
      shouldShowInvalidReferralWarning(signupCode: 'ABC', wasReferred: true),
      false,
    );
    expect(
      shouldShowInvalidReferralWarning(signupCode: '', wasReferred: false),
      false,
    );
    expect(
      shouldShowInvalidReferralWarning(signupCode: null, wasReferred: false),
      false,
    );
  });

  test('yeni hata kodları', () {
    String m(String c) => friendlyError(PostgrestException(message: c));
    expect(m('INVALID_DISCOUNT'), contains('geçersiz'));
    expect(m('DISCOUNT_EXCEEDS_ENTITLEMENT'), contains('hakkını'));
    expect(m('REFERRAL_NOT_FOUND'), contains('bulunamadı'));
    expect(m('DECISION_REQUIRED'), contains('karar'));
  });

  testWidgets('Referanslarım kod, sayı, oran ve kısa adı gösterir', (
    tester,
  ) async {
    final repo = FakeReferralRepository()
      ..summaryData = const ReferralSummary(
        userId: 'm1',
        referralCode: 'ABCDEFG',
        activeCount: 2,
        discountPercent: 10,
        approvedCount: 3,
        pendingCount: 1,
        wasReferred: false,
      )
      ..mine = [
        MyReferral(
          referralId: 'r1',
          displayName: 'Ayşe K.',
          status: ReferralStatus.approved,
          countsNow: true,
          createdAt: DateTime(2026, 11, 1),
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralRepositoryProvider.overrideWithValue(repo),
          signupReferralCodeProvider.overrideWithValue('ZZZZZZZ'),
        ],
        child: const MaterialApp(home: MyReferralsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABCDEFG'), findsOneWidget);
    expect(find.text('Sayılan referans: 2'), findsOneWidget);
    expect(find.text('Güncel indirim: %10'), findsOneWidget);
    expect(find.text('Ayşe K.'), findsOneWidget);
    expect(find.text('Sayılıyor'), findsOneWidget);
    expect(find.text(invalidReferralWarningText), findsOneWidget);
  });

  testWidgets('Admin referans onayı decide(approve=true) çağırır ve yeniler', (
    tester,
  ) async {
    final repo = FakeReferralRepository()
      ..admin = const [
        AdminReferral(
          id: 'r1',
          referrerId: 'a',
          referrerName: 'Ali Veli',
          referrerCode: 'ABCDEFG',
          referrerDiscountPercent: 5,
          referredId: 'b',
          referredName: 'Can Demir',
          referredHasActivePackage: true,
          status: ReferralStatus.pending,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [referralRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AdminReferralsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ali Veli'), findsOneWidget);
    final before = repo.adminListCalls;
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Onayla'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.decideCalls, [('r1', true)]);
    expect(repo.adminListCalls, greaterThan(before));
  });

  Future<FakePackageRepository> pumpAssign(
    WidgetTester tester,
    FakeReferralRepository refRepo,
  ) async {
    final pkgRepo = FakePackageRepository()
      ..defs = const [
        PackageDefinition(
          id: 'd1',
          categoryId: 'c1',
          categoryName: 'Reformer',
          name: '8 Derslik Paket',
          sessionCount: 8,
          validityDays: 30,
          price: 4000,
          isActive: true,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packageRepositoryProvider.overrideWithValue(pkgRepo),
          referralRepositoryProvider.overrideWithValue(refRepo),
        ],
        child: const MaterialApp(
          home: AdminMemberPackagesScreen(
            member: MemberSummary(id: 'm1', fullName: 'Ayşe Yılmaz'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paket ata'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8 Derslik Paket').last);
    await tester.pumpAndSettle();
    return pkgRepo;
  }

  const entitled15 = ReferralSummary(
    userId: 'm1',
    referralCode: 'ABCDEFG',
    activeCount: 3,
    discountPercent: 15,
    approvedCount: 3,
    pendingCount: 0,
    wasReferred: true,
  );

  testWidgets('Paket ata: hak 15, anahtar açık -> indirim 15 gönderilir', (
    tester,
  ) async {
    final refRepo = FakeReferralRepository()..summaryData = entitled15;
    final pkgRepo = await pumpAssign(tester, refRepo);
    expect(
      find.textContaining('Referans indirimi hakkı: %15 (3 aktif referans)'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('3.400 ₺'), findsOneWidget);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(pkgRepo.assignCalls.single.discount, 15);
  });

  testWidgets('Paket ata: anahtar kapalıyken indirim 0 gönderilir', (
    tester,
  ) async {
    final refRepo = FakeReferralRepository()..summaryData = entitled15;
    final pkgRepo = await pumpAssign(tester, refRepo);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(pkgRepo.assignCalls.single.discount, 0);
  });

  testWidgets('Paket ata: hak yoksa mesaj gösterilir ve 0 gönderilir', (
    tester,
  ) async {
    final pkgRepo = await pumpAssign(tester, FakeReferralRepository());
    expect(find.text('Bu üyenin referans indirimi hakkı yok.'), findsOneWidget);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(pkgRepo.assignCalls.single.discount, 0);
  });
}
