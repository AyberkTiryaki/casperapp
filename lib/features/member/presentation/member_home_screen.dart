import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../profile/profile.dart';

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(profile: profile, modules: const [
      ComingModule('Seans randevuları', Icons.event_available_outlined),
      ComingModule('Paketlerim ve seans hakkım', Icons.confirmation_number_outlined),
      ComingModule('Antrenman programım', Icons.fitness_center),
      ComingModule('Ölçümlerim ve ilerleme', Icons.monitor_weight_outlined),
    ]);
  }
}
