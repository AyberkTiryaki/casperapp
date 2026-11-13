import 'package:caspertrainingstudio/features/workouts/data/workout_repository.dart';
import 'package:caspertrainingstudio/features/workouts/domain/workout_models.dart';

class SaveCall {
  SaveCall({
    required this.memberId,
    required this.programId,
    required this.title,
    required this.goal,
    required this.notes,
    required this.items,
    required this.isActive,
  });
  final String memberId;
  final String? programId;
  final String title;
  final String? goal;
  final String? notes;
  final List<WorkoutItem> items;
  final bool isActive;
}

class FakeWorkoutRepository implements WorkoutRepository {
  List<WorkoutProgram> list = [];
  final saveCalls = <SaveCall>[];
  final activeCalls = <(String, bool)>[];

  @override
  Future<List<WorkoutProgram>> programs(String memberId) async => list;

  @override
  Future<void> saveProgram({
    required String memberId,
    String? programId,
    required String title,
    String? goal,
    String? notes,
    required List<WorkoutItem> items,
    required bool isActive,
  }) async {
    saveCalls.add(
      SaveCall(
        memberId: memberId,
        programId: programId,
        title: title,
        goal: goal,
        notes: notes,
        items: items,
        isActive: isActive,
      ),
    );
  }

  @override
  Future<void> setActive(String programId, bool isActive) async {
    activeCalls.add((programId, isActive));
  }
}

WorkoutProgram sampleProgram({
  String id = 'p1',
  String title = 'Güç Programı',
  bool isActive = true,
  DateTime? createdAt,
  List<WorkoutItem> items = const [
    WorkoutItem(
      dayLabel: 'Gün 1',
      exercise: 'Squat',
      sets: 3,
      reps: '12',
      restSeconds: 90,
    ),
  ],
}) => WorkoutProgram(
  id: id,
  memberId: 'm1',
  title: title,
  isActive: isActive,
  createdAt: createdAt ?? DateTime(2026, 11, 1),
  items: items,
);
