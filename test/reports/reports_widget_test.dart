import 'package:caspertrainingstudio/features/reports/data/report_repository.dart';
import 'package:caspertrainingstudio/features/reports/domain/report_models.dart';
import 'package:caspertrainingstudio/features/reports/presentation/admin_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_report_repo.dart';

Future<void> pumpScreen(WidgetTester tester, FakeReportRepository repo) async {
  tester.view.physicalSize = const Size(360, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reportRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: AdminReportsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('örnek rapor sayıları gösterilir', (tester) async {
    final repo = FakeReportRepository();
    await pumpScreen(tester, repo);

    expect(tester.takeException(), isNull);
    expect(find.text('Raporlar'), findsOneWidget);
    expect(find.text('12.300 ₺'), findsOneWidget);
    expect(find.text('5 paket · 600 ₺ indirim (2 pakette)'), findsOneWidget);
    expect(find.text('420 ₺'), findsOneWidget);
    expect(find.textContaining('4 satış · 7 adet'), findsOneWidget);
    expect(find.textContaining('1 iptal edilen satış hariç'), findsOneWidget);
    expect(find.text('750 ₺'), findsOneWidget);
    expect(find.text('3 yükleme'), findsOneWidget);
    expect(find.text('Aktif paketli üye'), findsOneWidget);
    expect(find.text('35 %'), findsOneWidget);
    expect(find.text('21 / 60 kontenjan'), findsOneWidget);
    expect(find.text('19 katıldı · 2 gelmedi'), findsOneWidget);
    expect(find.text('Ayşe Eğitmen'), findsOneWidget);
    expect(find.textContaining('8 ders · 17 / 48 kontenjan'), findsOneWidget);
    expect(find.text('Su'), findsOneWidget);
    expect(find.text('4 adet'), findsOneWidget);
    expect(find.text('80 ₺'), findsOneWidget);

    final now = DateTime.now();
    final month = currentMonthRange(now);
    expect(repo.calls.single, month);
  });

  testWidgets('Geçen ay çipi önceki ay aralığıyla çağırır', (tester) async {
    final repo = FakeReportRepository();
    await pumpScreen(tester, repo);

    await tester.tap(find.text('Geçen ay'));
    await tester.pumpAndSettle();

    expect(repo.calls.length, 2);
    expect(repo.calls.last, previousMonthRange(DateTime.now()));
  });

  testWidgets('boş listeler tek satırlık metin gösterir', (tester) async {
    final repo = FakeReportRepository()
      ..report = AdminReport.fromJson(const {});
    await pumpScreen(tester, repo);

    expect(find.text('Bu aralıkta yapılan ders yok.'), findsOneWidget);
    expect(find.text('Bu aralıkta ürün satışı yok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repo hatası hata görünümü gösterir', (tester) async {
    final repo = FakeReportRepository()
      ..error = const PostgrestException(message: 'FORBIDDEN');
    await pumpScreen(tester, repo);

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Gelir'), findsNothing);
  });
}
