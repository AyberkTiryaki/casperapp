import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
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

  MemberPackage pkg(String cat) => MemberPackage(
    id: 'p-$cat',
    memberId: 'm',
    definitionId: 'd',
    categoryId: cat,
    totalCredits: 8,
    remainingCredits: 5,
    pricePaid: 100,
    activatedAt: DateTime.now().subtract(const Duration(days: 2)),
    endsAt: DateTime.now().add(const Duration(days: 20)),
    status: 'active',
  );

  Future<void> pump(
    WidgetTester tester,
    List<StudioClass> data, {
    List<MemberPackage> packages = const [],
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPackagesProvider.overrideWith((ref) async => packages),
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

  testWidgets('Paketime uygun is default and hides other categories', (
    tester,
  ) async {
    await pump(tester, all, packages: [pkg('c1')]);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Paketime uygun'))
          .selected,
      isTrue,
    );
    // Bugün: c1 (a) görünür, c2 (b) gizli.
    expect(find.text('Dolu'), findsOneWidget);
    expect(find.text('1 yer kaldı'), findsNothing);
    expect(find.text('Paketin bu ders için geçerli değil'), findsNothing);
    // Tümü: kapsanmayan ders kilit satırıyla görünür.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tümü'));
    await tester.pumpAndSettle();
    expect(find.text('1 yer kaldı'), findsOneWidget);
    expect(find.text('Paketin bu ders için geçerli değil'), findsOneWidget);
  });

  testWidgets('without active package default is Tümü, no lock line', (
    tester,
  ) async {
    await pump(tester, all);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tümü'))
          .selected,
      isTrue,
    );
    expect(find.text('1 yer kaldı'), findsOneWidget);
    expect(find.text('Paketin bu ders için geçerli değil'), findsNothing);
  });
}
