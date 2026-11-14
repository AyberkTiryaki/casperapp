import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/member/class_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

StudioClass _c(
  String id,
  DateTime day,
  int hour, {
  String cat = 'c1',
  String catName = 'Pilates',
  int capacity = 5,
  int booked = 0,
}) => StudioClass(
  id: id,
  trainerId: 't',
  trainerName: 'Ayşe',
  categoryId: cat,
  categoryName: catName,
  classType: ClassType.group,
  capacity: capacity,
  bookedCount: booked,
  startsAt: DateTime(day.year, day.month, day.day, hour),
  endsAt: DateTime(day.year, day.month, day.day, hour, 50),
  status: 'scheduled',
);

void main() {
  final today = dayStart(DateTime.now());
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final all = [
    _c('a', today, 9, capacity: 4, booked: 4),
    _c('b', today, 11, cat: 'c2', catName: 'Yoga', capacity: 4, booked: 3),
    _c('c', tomorrow, 10, cat: 'c2', catName: 'Yoga'),
  ];

  Future<void> pump(WidgetTester tester, List<StudioClass> data) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith(
            (ref, q) async =>
                data.where((c) => dayStart(c.startsAt) == q.day).toList(),
          ),
        ],
        child: const MaterialApp(home: ClassCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('capacity badges', (tester) async {
    await pump(tester, all);
    expect(find.text('Dolu'), findsOneWidget);
    expect(find.text('1 yer kaldı'), findsOneWidget);
  });

  testWidgets('day selection filters list', (tester) async {
    await pump(tester, all);
    await tester.tap(find.text('${tomorrow.day}').first);
    await tester.pumpAndSettle();
    expect(find.text('Dolu'), findsNothing);
    expect(find.text('5 yer'), findsOneWidget);
  });

  testWidgets('category filter and empty state', (tester) async {
    await pump(tester, all);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yoga'));
    await tester.pumpAndSettle();
    expect(find.text('Dolu'), findsNothing);
    expect(find.text('1 yer kaldı'), findsOneWidget);
    await tester.tap(find.text('${tomorrow.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pilates'));
    await tester.pumpAndSettle();
    expect(find.text('Bu kategoride ders yok'), findsOneWidget);
  });

  testWidgets('empty day suggests next day', (tester) async {
    await pump(tester, [_c('c', tomorrow, 10)]);
    expect(find.text('5 yer'), findsOneWidget);
    final day2 = DateTime(today.year, today.month, today.day + 2);
    await tester.tap(find.text('${day2.day}').first);
    await tester.pumpAndSettle();
    expect(find.text('Bu gün için ders yok'), findsOneWidget);
  });
}
