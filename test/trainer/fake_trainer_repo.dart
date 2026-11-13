import 'package:caspertrainingstudio/features/trainer/data/trainer_repository.dart';
import 'package:caspertrainingstudio/features/trainer/domain/trainer_models.dart';

class FakeTrainerRepository implements TrainerRepository {
  FakeTrainerRepository([this.members = const []]);

  List<TrainerMember> members;
  final calls = <String?>[];

  @override
  Future<List<TrainerMember>> myMembers({String? trainerId}) async {
    calls.add(trainerId);
    return members;
  }
}
