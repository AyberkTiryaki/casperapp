import 'package:caspertrainingstudio/features/measurements/data/measurement_repository.dart';
import 'package:caspertrainingstudio/features/measurements/domain/measurement_models.dart';
import 'package:caspertrainingstudio/features/measurements/presentation/my_measurements_screen.dart';
import 'package:caspertrainingstudio/features/measurements/presentation/weight_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_measurement_repo.dart';

Widget app(
  FakeMeasurementRepository repo,
  Widget home, {
  bool consent = true,
}) => ProviderScope(
  overrides: [
    measurementRepositoryProvider.overrideWithValue(repo),
    healthConsentProvider.overrideWith((ref, id) async => consent),
  ],
  child: MaterialApp(home: home),
);

List<BodyMeasurement> threeRows() => [
  sampleMeasurement('c', '2026-11-10', weight: 73.5, waist: 80),
  sampleMeasurement('b', '2026-10-25', weight: 73),
  sampleMeasurement('a', '2026-10-01', weight: 75, note: 'Başlangıç'),
];

void main() {
  testWidgets('son değer ve iki değişim satırı gösterilir', (tester) async {
    final repo = FakeMeasurementRepository()..rows = threeRows();
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ölçümlerim ve ilerleme'), findsOneWidget);
    expect(find.text('73,5 kg'), findsOneWidget);
    expect(find.text('Öncekine göre +0,5 kg'), findsOneWidget);
    expect(find.text('İlk ölçüme göre -1,5 kg'), findsOneWidget);
    expect(find.text('Başlangıç', skipOffstage: false), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(WeightTrendChart),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('boş durum ve FAB', (tester) async {
    final repo = FakeMeasurementRepository();
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz ölçüm yok'), findsOneWidget);
    expect(
      find.text('İlk ölçümünüzü ekleyerek ilerlemenizi takip edin.'),
      findsOneWidget,
    );
    expect(find.text('Ölçüm ekle'), findsOneWidget);
  });

  testWidgets('onay yoksa uyarı gösterilir, FAB gizlenir', (tester) async {
    final repo = FakeMeasurementRepository();
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1'), consent: false),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('sağlık verisi onayınız yok'), findsOneWidget);
    expect(find.text('Ölçüm ekle'), findsNothing);
  });

  testWidgets('tek kilo ölçümünde grafik yerine açıklama', (tester) async {
    final repo = FakeMeasurementRepository()
      ..rows = [sampleMeasurement('a', '2026-11-01', weight: 70)];
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Eğilim çizgisi için en az iki kilo ölçümü gerekir.'),
      findsOneWidget,
    );
  });

  testWidgets('iki nokta grafiği çizer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeightTrendChart(
            points: [
              TrendPoint(DateTime(2026, 11, 1), 72),
              TrendPoint(DateTime(2026, 11, 8), 71),
            ],
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(WeightTrendChart),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('en az iki'), findsNothing);
  });

  testWidgets('ekleme akışı: kilo girilip kaydedilir', (tester) async {
    final repo = FakeMeasurementRepository();
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ölçüm ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Kilo'), '72,5');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.addCalls.length, 1);
    expect(repo.addCalls[0].memberId, 'm1');
    expect(repo.addCalls[0].values, {MeasurementMetric.weight: 72.5});
    expect(find.text('Ölçüm kaydedildi.'), findsOneWidget);
  });

  testWidgets('hiçbir şey girilmezse doğrulama mesajı, kayıt yok', (
    tester,
  ) async {
    final repo = FakeMeasurementRepository();
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ölçüm ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('En az bir ölçüm değeri girin.'), findsOneWidget);
    expect(repo.addCalls, isEmpty);
  });

  testWidgets('silme onayı repo.delete çağırır', (tester) async {
    final repo = FakeMeasurementRepository()
      ..rows = [sampleMeasurement('a', '2026-11-01', weight: 70)];
    await tester.pumpWidget(
      app(repo, const MyMeasurementsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    expect(find.text('Bu ölçüm silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['a']);
  });
}
