import 'package:caspertrainingstudio/features/schedule/presentation/shared/schedule_widgets.dart';
import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/trainer/trainer_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trainer day strip marks days returned by classDays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final today = dayStart(DateTime.now());
    final marked = DateTime(today.year, today.month, today.day + 1);
    ClassDaysQuery? seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith((ref, q) async => []),
          classDaysProvider.overrideWith((ref, q) async {
            seen = q;
            return {marked};
          }),
        ],
        child: const MaterialApp(home: TrainerCalendarScreen(trainerId: 't1')),
      ),
    );
    await tester.pumpAndSettle();

    final chips = tester.widgetList<DayChip>(find.byType(DayChip)).toList();
    expect(chips.where((c) => c.marked).map((c) => c.day), [marked]);
    expect(seen?.trainerId, 't1');
    expect(seen?.days, 14);
  });
}
