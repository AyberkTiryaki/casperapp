import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../packages/presentation/member/my_packages_screen.dart';
import '../../profile/profile.dart';
import '../../referrals/presentation/my_referrals_screen.dart';

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(profile: profile, modules: [
      ComingModule('Paketlerim', Icons.confirmation_number_outlined,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyPackagesScreen()))),
      ComingModule('Referanslarım', Icons.group_add_outlined,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReferralsScreen()))),
      const ComingModule('Seans randevuları', Icons.event_available_outlined),
      const ComingModule('Antrenman programım', Icons.fitness_center),
      const ComingModule('Ölçümlerim ve ilerleme', Icons.monitor_weight_outlined),
    ]);
  }
}
