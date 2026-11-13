import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../domain/workout_models.dart';

abstract class WorkoutRepository {
  Future<List<WorkoutProgram>> programs(String memberId);
  Future<void> saveProgram({
    required String memberId,
    String? programId,
    required String title,
    String? goal,
    String? notes,
    required List<WorkoutItem> items,
    required bool isActive,
  });
  Future<void> setActive(String programId, bool isActive);
}

class SupabaseWorkoutRepository implements WorkoutRepository {
  @override
  Future<List<WorkoutProgram>> programs(String memberId) async {
    final r = await supabase
        .from('workout_programs')
        .select('*, workout_program_items(*)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (r as List)
        .map(
          (e) => WorkoutProgram.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  @override
  Future<void> saveProgram({
    required String memberId,
    String? programId,
    required String title,
    String? goal,
    String? notes,
    required List<WorkoutItem> items,
    required bool isActive,
  }) => supabase.rpc(
    'save_workout_program',
    params: {
      'p_member_id': memberId,
      'p_title': title,
      'p_goal': goal,
      'p_notes': notes,
      'p_items': items.map((e) => e.toJson()).toList(),
      'p_program_id': programId,
      'p_is_active': isActive,
    },
  );

  @override
  Future<void> setActive(String programId, bool isActive) => supabase.rpc(
    'set_workout_program_active',
    params: {'p_program_id': programId, 'p_is_active': isActive},
  );
}

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => SupabaseWorkoutRepository(),
);

final workoutProgramsProvider =
    FutureProvider.family<List<WorkoutProgram>, String>(
      (ref, memberId) =>
          ref.watch(workoutRepositoryProvider).programs(memberId),
    );
