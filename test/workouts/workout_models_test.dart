import 'package:caspertrainingstudio/features/workouts/domain/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workout_repo.dart';

void main() {
  test(
    'fromJson iç içe öğeleri sort_order ile sıralar, metin sayıları okur',
    () {
      final p = WorkoutProgram.fromJson({
        'id': 'p1',
        'member_id': 'm1',
        'title': 'Program',
        'goal': null,
        'notes': 'Not',
        'is_active': true,
        'created_by': 't1',
        'created_at': '2026-11-01T10:00:00Z',
        'workout_program_items': [
          {
            'id': 'i2',
            'day_label': 'Gün 1',
            'exercise': 'Plank',
            'sets': '2',
            'reps': '30 sn',
            'rest_seconds': '45',
            'note': null,
            'sort_order': '2',
          },
          {
            'id': 'i1',
            'day_label': 'Gün 1',
            'exercise': 'Squat',
            'sets': 3,
            'reps': '12',
            'rest_seconds': 60,
            'note': 'Yavaş',
            'sort_order': 1,
          },
        ],
      });
      expect(p.items.map((e) => e.exercise), ['Squat', 'Plank']);
      expect(p.items[1].sets, 2);
      expect(p.items[1].restSeconds, 45);
      expect(p.goal, isNull);
      expect(p.createdBy, 't1');
      expect(p.isActive, true);
    },
  );

  test('fromJson öğe listesi yoksa boş liste', () {
    final p = WorkoutProgram.fromJson({
      'id': 'p1',
      'member_id': 'm1',
      'title': 'P',
      'is_active': false,
      'created_at': '2026-11-01T10:00:00Z',
    });
    expect(p.items, isEmpty);
  });

  test('toJson p_items şeklini üretir', () {
    const i = WorkoutItem(
      dayLabel: 'Gün 1',
      exercise: 'Squat',
      sets: 3,
      reps: '12',
      restSeconds: 60,
    );
    expect(i.toJson(), {
      'day_label': 'Gün 1',
      'exercise': 'Squat',
      'sets': 3,
      'reps': '12',
      'rest_seconds': 60,
      'note': null,
    });
  });

  test('groupItemsByDay ilk görünüş sırasını korur', () {
    const a = WorkoutItem(dayLabel: 'B', exercise: '1');
    const b = WorkoutItem(dayLabel: 'A', exercise: '2');
    const c = WorkoutItem(dayLabel: 'B', exercise: '3');
    final g = groupItemsByDay([a, b, c]);
    expect(g.map((e) => e.key), ['B', 'A']);
    expect(g[0].value, [a, c]);
    expect(g[1].value, [b]);
  });

  test('sortPrograms aktif önce, sonra yeniden eskiye', () {
    final old = sampleProgram(
      id: 'old',
      isActive: false,
      createdAt: DateTime(2026, 1, 1),
    );
    final newer = sampleProgram(
      id: 'new',
      isActive: false,
      createdAt: DateTime(2026, 6, 1),
    );
    final act = sampleProgram(
      id: 'act',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );
    expect(sortPrograms([old, newer, act]).map((e) => e.id), [
      'act',
      'new',
      'old',
    ]);
  });

  test('formatRest', () {
    expect(formatRest(90), '1 dk 30 sn');
    expect(formatRest(60), '1 dk');
    expect(formatRest(45), '45 sn');
    expect(formatRest(0), '0 sn');
  });
}
