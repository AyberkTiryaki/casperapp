import 'package:caspertrainingstudio/core/theme/app_colors.dart';
import 'package:caspertrainingstudio/features/home/home_tab.dart';
import 'package:caspertrainingstudio/features/member/presentation/member_dashboard.dart';
import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../packages/fake_repo.dart';

Widget host({
  required List<MemberPackage> packages,
  List<MyReservation> reservations = const [],
}) => ProviderScope(
  overrides: [
    myPackagesProvider.overrideWith((ref) async => packages),
    myReservationsProvider.overrideWith((ref) async => reservations),
  ],
  child: const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: MemberDashboard())),
  ),
);

void main() {
  testWidgets('paketi yoksa "Ders almak için paket gerekli" kartı çıkar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(packages: const []));
    await tester.pumpAndSettle();
    expect(find.text('Ders almak için paket gerekli'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Ders bul'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aktif paket kalan hak ve ilerleme çubuğuyla gösterilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(packages: [samplePackage()]));
    await tester.pumpAndSettle();
    expect(find.text('Reformer'), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
    expect(
      find.textContaining('/ 8 ders'),
      findsOneWidget,
      reason: 'kalan/toplam',
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(5 / 8, 0.001));
    expect(bar.color, AppColors.cyan);
    expect(find.text('Ders almak için paket gerekli'), findsNothing);
  });

  testWidgets('az hak kalınca amber uyarı tonu', (tester) async {
    await tester.pumpWidget(host(packages: [samplePackage(remaining: 1)]));
    await tester.pumpAndSettle();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.color, AppColors.warning);
  });

  testWidgets('Ders bul düğmesi Takvim sekmesine geçirir', (tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPackagesProvider.overrideWith((ref) async => const []),
          myReservationsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const SingleChildScrollView(child: MemberDashboard());
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ders bul'));
    expect(captured.read(homeTabProvider), HomeTabs.second);
  });
}
