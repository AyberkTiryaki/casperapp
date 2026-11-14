import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/shared/schedule_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = dayStart(DateTime.now());

  void setSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'DayStrip auto-scrolls so today is visible (offset -7, 28 days)',
    (tester) async {
      setSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayStrip(
              selected: today,
              onSelected: (_) {},
              startOffset: -7,
              days: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bugün'), findsOneWidget);
      final rect = tester.getRect(find.text('Bugün'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    },
  );

  testWidgets('DayStrip scrolls to a programmatically changed selection', (
    tester,
  ) async {
    setSize(tester);
    final later = DateTime(today.year, today.month, today.day + 18);
    final sel = ValueNotifier<DateTime>(today);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<DateTime>(
            valueListenable: sel,
            builder: (_, d, _) => DayStrip(
              selected: d,
              onSelected: (_) {},
              startOffset: -7,
              days: 28,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    sel.value = later;
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(DayChip, '${later.day}');
    expect(chip, findsWidgets);
    final r = tester.getRect(
      find.byWidgetPredicate((w) => w is DayChip && w.day == later),
    );
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(360));
  });

  testWidgets('trainer ClassListView card shows capacity badge', (
    tester,
  ) async {
    setSize(tester);
    final item = StudioClass(
      id: 'a',
      trainerId: 't',
      trainerName: 'Ayşe',
      categoryId: 'c1',
      categoryName: 'Pilates',
      classType: ClassType.group,
      capacity: 5,
      bookedCount: 4,
      startsAt: DateTime(today.year, today.month, today.day, 9),
      endsAt: DateTime(today.year, today.month, today.day, 9, 50),
      status: 'scheduled',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith((ref, q) async => [item]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ClassListView(
              query: (
                day: today,
                categoryId: null,
                trainerId: 't',
                includeCancelled: false,
              ),
              showTrainer: false,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 yer kaldı'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('Ayşe'), findsNothing);
  });
}
