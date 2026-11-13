import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../domain/trainer_models.dart';

abstract class TrainerRepository {
  Future<List<TrainerMember>> myMembers({String? trainerId});
}

class SupabaseTrainerRepository implements TrainerRepository {
  @override
  Future<List<TrainerMember>> myMembers({String? trainerId}) async {
    final r = await supabase.rpc(
      'trainer_my_members',
      params: trainerId == null ? null : {'p_trainer_id': trainerId},
    );
    return (r as List)
        .map((e) => TrainerMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final trainerRepositoryProvider = Provider<TrainerRepository>(
  (ref) => SupabaseTrainerRepository(),
);

final trainerMembersProvider =
    FutureProvider.family<List<TrainerMember>, String?>(
      (ref, trainerId) =>
          ref.watch(trainerRepositoryProvider).myMembers(trainerId: trainerId),
    );
