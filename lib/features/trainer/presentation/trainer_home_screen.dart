import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../profile/profile.dart';

class TrainerHomeScreen extends StatelessWidget {
  const TrainerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(profile: profile, modules: const [
      ComingModule('Günlük seans takvimi', Icons.calendar_month_outlined),
      ComingModule('Üyelerim', Icons.groups_outlined),
      ComingModule('Antrenman programı hazırlama', Icons.fitness_center),
      ComingModule('Üye ölçümleri', Icons.monitor_weight_outlined),
    ]);
  }
}
