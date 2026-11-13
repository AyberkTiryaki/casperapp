import 'package:caspertrainingstudio/features/trainer/data/trainer_repository.dart';
import 'package:caspertrainingstudio/features/trainer/domain/trainer_models.dart';
import 'package:caspertrainingstudio/features/trainer/presentation/my_members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_trainer_repo.dart';

TrainerMember m(String name, {DateTime? last, DateTime? next, int n = 0}) =>
    TrainerMember(
      memberId: 'id-$name',
      fullName: name,
      lastClassAt: last,
      nextClassAt: next,
      classCount: n,
    );

Future<void> pump(
  WidgetTester tester,
  FakeTrainerRepository repo, {
  void Function(BuildContext, TrainerMember)? onTap,
  String? hint,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [trainerRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: MyMembersScreen(hint: hint, onMemberTap: onTap ?? (_, _) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('fromJson: boş tarihler null olur', () {
    final x = TrainerMember.fromJson({
      'member_id': 'a',
      'full_name': 'Ali',
      'last_class_at': null,
      'next_class_at': null,
      'class_count': 2,
    });
    expect(x.lastClassAt, isNull);
    expect(x.nextClassAt, isNull);
    expect(x.classCount, 2);

    final y = TrainerMember.fromJson({
      'member_id': 'a',
      'full_name': 'Ali',
      'last_class_at': '2026-11-12T07:00:00Z',
      'next_class_at': '2026-11-14T07:00:00Z',
      'class_count': 3,
    });
    expect(y.lastClassAt, DateTime.utc(2026, 11, 12, 7));
    expect(y.nextClassAt, isNotNull);
  });

  test('filterMembers: büyük/küçük harf ve Türkçe İ/ı', () {
    final all = [m('İlkay Yılmaz'), m('Ayşe Işık'), m('Ali')];
    expect(filterMembers(all, ''), all);
    expect(filterMembers(all, '  '), all);
    expect(filterMembers(all, 'ilkay').map((e) => e.fullName), [
      'İlkay Yılmaz',
    ]);
    expect(filterMembers(all, 'İLKAY').map((e) => e.fullName), [
      'İlkay Yılmaz',
    ]);
    expect(filterMembers(all, 'ışık').map((e) => e.fullName), ['Ayşe Işık']);
    expect(filterMembers(all, 'IŞIK').map((e) => e.fullName), ['Ayşe Işık']);
    expect(filterMembers(all, 'yok'), isEmpty);
  });

  testWidgets('liste adları ve üç alt satırı gösterir', (tester) async {
    final repo = FakeTrainerRepository([
      m(
        'Ayşe Yılmaz',
        last: DateTime(2026, 11, 12, 10),
        next: DateTime(2026, 11, 14, 10),
        n: 3,
      ),
      m('Burak Kaya'),
    ]);
    await pump(tester, repo, hint: 'Program hazırlamak için üye seçin');

    expect(find.text('Program hazırlamak için üye seçin'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Burak Kaya'), findsOneWidget);
    expect(
      find.text(
        'Son ders: 12.11.2026 10:00\n'
        'Sonraki ders: 14.11.2026 10:00\n'
        '3 ders (son 90 gün ve gelecek)',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Son ders: —\nSonraki ders: —\n0 ders (son 90 gün ve gelecek)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('arama listeyi süzer, eşleşme yoksa boş görünüm', (tester) async {
    final repo = FakeTrainerRepository([m('Ayşe Yılmaz'), m('Burak Kaya')]);
    await pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'burak');
    await tester.pumpAndSettle();
    expect(find.text('Burak Kaya'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Üye bulunamadı'), findsOneWidget);
  });

  testWidgets('satıra dokunma onMemberTap çağırır', (tester) async {
    final repo = FakeTrainerRepository([m('Ayşe Yılmaz'), m('Burak Kaya')]);
    final tapped = <TrainerMember>[];
    await pump(tester, repo, onTap: (_, mem) => tapped.add(mem));

    await tester.tap(find.text('Burak Kaya'));
    await tester.pumpAndSettle();
    expect(tapped.single.memberId, 'id-Burak Kaya');
  });

  testWidgets('üye yoksa boş durum gösterilir', (tester) async {
    await pump(tester, FakeTrainerRepository());
    expect(find.text('Henüz üyeniz yok'), findsOneWidget);
    expect(
      find.text('Derslerinize rezervasyon yapan üyeler burada görünür.'),
      findsOneWidget,
    );
  });
}
