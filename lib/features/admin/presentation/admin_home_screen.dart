import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../profile/profile.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(profile: profile, modules: const [
      ComingModule('Kullanıcı ve rol yönetimi', Icons.manage_accounts_outlined),
      ComingModule('Paket ve seans yönetimi', Icons.inventory_2_outlined),
      ComingModule('Antrenör ve takvim yönetimi', Icons.event_note_outlined),
      ComingModule('Raporlar', Icons.bar_chart_outlined),
    ]);
  }
}
