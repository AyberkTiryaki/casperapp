import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caspertrainingstudio/demo/data/demo_data.dart';
import 'package:caspertrainingstudio/demo/data/studio_store.dart';
import 'package:caspertrainingstudio/demo/demo_main.dart';
import 'package:caspertrainingstudio/demo/models/models.dart';
import 'package:caspertrainingstudio/demo/screens/workouts_screen.dart';

void main() {
  group('StudioStore', () {
    late StudioStore store;
    setUp(() => store = buildDemoStore());

    test('süresi dolmuş üye derse kaydedilemez', () {
      final expired = store.members.firstWhere((m) => m.isExpired);
      final c = store.classes.firstWhere((c) => !c.isFull);
      expect(store.toggleBooking(c.id, expired.id), isNotNull);
      expect(c.attendeeIds.contains(expired.id), isFalse);
    });

    test('dolu derse kayıt yapılmaz', () {
      final c = store.addClass(
        title: 'Test',
        trainerId: store.trainers.first.id,
        start: DateTime.now().add(const Duration(hours: 2)),
        duration: const Duration(minutes: 60),
        capacity: 1,
      );
      final active = store.members.where((m) => !m.isExpired).toList();
      expect(store.toggleBooking(c.id, active[0].id), isNull);
      expect(store.toggleBooking(c.id, active[1].id), 'Ders kontenjanı dolu.');
      expect(c.attendeeIds.length, 1);
    });

    test('üyelik yenileme süresi dolmuş üyeyi bugünden itibaren uzatır', () {
      final m = store.members.firstWhere((m) => m.isExpired);
      store.renewMembership(m.id);
      expect(m.daysLeft(), m.membership.days);
    });

    test('üye silinince rezervasyonları da silinir', () {
      final c = store.classes.firstWhere((c) => c.attendeeIds.isNotEmpty);
      final memberId = c.attendeeIds.first;
      store.deleteMember(memberId);
      expect(store.memberById(memberId), isNull);
      expect(store.classes.any((c) => c.attendeeIds.contains(memberId)),
          isFalse);
    });

    test('program silinince üyelerden kaldırılır', () {
      store.deleteProgram('p1');
      expect(store.members.any((m) => m.programId == 'p1'), isFalse);
    });
  });

  test('egzersiz satırları ayrıştırılır', () {
    final list = parseExercises('Squat - 4x10\nPlank – 3x45 sn\n\nŞınav');
    expect(list.length, 3);
    expect((list[0].name, list[0].sets, list[0].reps), ('Squat', 4, '10'));
    expect((list[1].name, list[1].sets, list[1].reps), ('Plank', 3, '45 sn'));
    expect((list[2].name, list[2].sets, list[2].reps), ('Şınav', 3, '10'));
  });

  testWidgets('menüler arasında gezinilebilir', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CasperApp(store: buildDemoStore()));
    await tester.pumpAndSettle();
    expect(find.text('Bugünkü Dersler'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Demir'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Kuvvet – Üst/Alt'), findsOneWidget);
  });

  testWidgets('telefon genişliğinde alt menü görünür', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CasperApp(store: buildDemoStore()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('üye baş harfleri', () {
    final m = Member(
      id: 'x',
      name: 'ayşe  nur demir',
      phone: '',
      membership: MembershipType.aylik,
      membershipEnd: DateTime.now(),
    );
    expect(m.initials, 'AN');
  });
}
