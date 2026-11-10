import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/referrals/data/referral_repository.dart';
import 'package:caspertrainingstudio/features/packages/presentation/admin/definitions_screen.dart';
import 'package:caspertrainingstudio/features/packages/presentation/admin/member_packages_screen.dart';
import 'package:caspertrainingstudio/features/packages/presentation/member/my_packages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../referrals/referrals_test.dart' show FakeReferralRepository;
import 'fake_repo.dart';

Widget app(FakePackageRepository repo, Widget home) => ProviderScope(
      overrides: [
        packageRepositoryProvider.overrideWithValue(repo),
        referralRepositoryProvider.overrideWithValue(FakeReferralRepository()),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  testWidgets('Paketlerim aktif paketi kalan hakla gösterir', (tester) async {
    final repo = FakePackageRepository()..pkgs = [samplePackage()];
    await tester.pumpWidget(app(repo, const MyPackagesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Aktif paketler'), findsOneWidget);
    expect(find.text('8 Derslik Paket'), findsOneWidget);
    expect(find.text('Kalan hak: 5 / 8'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
  });

  testWidgets('Paket ata: ACTIVE_PACKAGE_EXISTS sonrası aynı anahtarla yenileme',
      (tester) async {
    final repo = FakePackageRepository()
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
        )
      ]
      ..assignErrorOnFirst =
          const PostgrestException(message: 'ACTIVE_PACKAGE_EXISTS');
    await tester.pumpWidget(app(
        repo,
        const AdminMemberPackagesScreen(
            member: MemberSummary(id: 'm1', fullName: 'Ayşe Yılmaz'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paket ata'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8 Derslik Paket').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();

    expect(find.text('Aktif paket var'), findsOneWidget);
    expect(repo.assignCalls.length, 1);
    expect(repo.assignCalls[0].replace, false);

    await tester.tap(find.text('Sonlandır ve ata'));
    await tester.pumpAndSettle();

    expect(repo.assignCalls.length, 2);
    expect(repo.assignCalls[1].replace, true);
    expect(repo.assignCalls[1].key, repo.assignCalls[0].key);
    expect(find.text('Paket atandı.'), findsOneWidget);
  });

  testWidgets('Tanım formu 16 ders için validity_days 40 gönderir',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakePackageRepository()
      ..cats = const [Category(id: 'c1', name: 'Reformer', isActive: true)];
    await tester.pumpWidget(app(
        repo,
        Builder(
            builder: (ctx) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => const DefinitionFormScreen())),
                    child: const Text('ac'),
                  ),
                ))));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reformer').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad'), '16 Derslik');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16 ders').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Geçerlilik: 40 gün'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fiyat (TL)'), '7500,50');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.createdDefs.length, 1);
    expect(repo.createdDefs.single['validityDays'], 40);
    expect(repo.createdDefs.single['sessionCount'], 16);
    expect(repo.createdDefs.single['price'], 7500.5);
  });
}
