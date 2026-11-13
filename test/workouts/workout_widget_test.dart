import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:caspertrainingstudio/features/workouts/data/workout_repository.dart';
import 'package:caspertrainingstudio/features/workouts/presentation/member_programs_screen.dart';
import 'package:caspertrainingstudio/features/workouts/presentation/my_programs_screen.dart';
import 'package:caspertrainingstudio/features/workouts/presentation/program_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workout_repo.dart';

Widget app(FakeWorkoutRepository repo, Widget home) => ProviderScope(
  overrides: [
    workoutRepositoryProvider.overrideWithValue(repo),
    trainersProvider.overrideWith((ref) async => <TrainerSummary>[]),
  ],
  child: MaterialApp(home: home),
);

void main() {
  testWidgets('Programım aktif programı ve önceki programları gösterir', (
    tester,
  ) async {
    final repo = FakeWorkoutRepository()
      ..list = [
        sampleProgram(
          id: 'old',
          title: 'Eski Program',
          isActive: false,
          createdAt: DateTime(2026, 1, 1),
        ),
        sampleProgram(id: 'act', title: 'Güncel Program'),
      ];
    await tester.pumpWidget(app(repo, const MyProgramsScreen(memberId: 'm1')));
    await tester.pumpAndSettle();
    expect(find.text('Antrenman programım'), findsOneWidget);
    expect(find.text('Güncel Program'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('3 set x 12  •  Dinlenme: 1 dk 30 sn'), findsOneWidget);
    expect(find.text('Önceki programlar'), findsOneWidget);
    expect(find.text('Eski Program'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Güncel Program')).dy,
      lessThan(tester.getTopLeft(find.text('Eski Program')).dy),
    );
  });

  testWidgets('Programım boş durum', (tester) async {
    await tester.pumpWidget(
      app(FakeWorkoutRepository(), const MyProgramsScreen(memberId: 'm1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz programınız yok'), findsOneWidget);
    expect(
      find.text('Eğitmeniniz size bir program hazırladığında burada görünür.'),
      findsOneWidget,
    );
  });

  testWidgets('Üye programları: pasife alma onaydan sonra setActive çağırır', (
    tester,
  ) async {
    final repo = FakeWorkoutRepository()..list = [sampleProgram()];
    await tester.pumpWidget(
      app(
        repo,
        const MemberProgramsScreen(memberId: 'm1', memberName: 'Ayşe Yılmaz'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Pasife al'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Vazgeç'));
    await tester.pumpAndSettle();
    expect(repo.activeCalls, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Pasife al'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pasife al'));
    await tester.pumpAndSettle();
    expect(repo.activeCalls, [('p1', false)]);
    expect(find.text('Program pasife alındı.'), findsOneWidget);
  });

  testWidgets('Editör: egzersiz ekleyip kaydeder', (tester) async {
    final repo = FakeWorkoutRepository();
    await tester.pumpWidget(
      app(
        repo,
        Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => const ProgramEditorScreen(
                    memberId: 'm1',
                    memberName: 'Ayşe',
                  ),
                ),
              ),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), 'Güç');
    await tester.tap(find.text('Egzersiz ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Egzersiz'),
      'Squat',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Set'), '3');
    await tester.enterText(find.widgetWithText(TextFormField, 'Tekrar'), '12');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dinlenme (saniye)'),
      '60',
    );
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Squat'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.saveCalls.length, 1);
    final c = repo.saveCalls.single;
    expect(c.memberId, 'm1');
    expect(c.programId, isNull);
    expect(c.title, 'Güç');
    expect(c.goal, isNull);
    expect(c.isActive, true);
    expect(c.items.single.toJson(), {
      'day_label': 'Gün 1',
      'exercise': 'Squat',
      'sets': 3,
      'reps': '12',
      'rest_seconds': 60,
      'note': null,
    });
    expect(find.byType(ProgramEditorScreen), findsNothing);
  });

  testWidgets('Editör: egzersiz yoksa kaydetmez', (tester) async {
    final repo = FakeWorkoutRepository();
    await tester.pumpWidget(
      app(repo, const ProgramEditorScreen(memberId: 'm1', memberName: 'Ayşe')),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), 'Güç');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('En az bir egzersiz ekleyin.'), findsOneWidget);
    expect(repo.saveCalls, isEmpty);
  });
}
